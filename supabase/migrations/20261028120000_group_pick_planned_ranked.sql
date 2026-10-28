-- ============================================================================
-- Migration: Planned group picks with ranked (top-3, Borda) voting
-- ============================================================================
-- NOT YET APPLIED. There is no staging Supabase project; production needs Drew's approval.
-- Additive: existing "tonight" yes/no picks keep working unchanged (mode = 'now').
--
--   * group_picks.mode ('now' | 'planned'), group_picks.event_at (optional date/time of the outing)
--   * group_pick_rankings: each member ranks up to 3 places (rank 1..3)
--   * Borda points: 1st = 3, 2nd = 2, 3rd = 1. Ties: more 1st places, then more 2nds, then list order.
--   * Planned picks close at decide_at (voting deadline, default = day before event_at, else +24h)
--     or early when every member (>= 2) has ranked. On close every member gets a push with the top 3.
--   * RPCs: create_planned_group_pick, rank_group_pick, get_planned_group_pick
--     invite_group_pick_members / add_group_pick_places / share links work unchanged.
-- ============================================================================

ALTER TABLE public.group_picks
    ADD COLUMN IF NOT EXISTS mode TEXT NOT NULL DEFAULT 'now' CHECK (mode IN ('now', 'planned')),
    ADD COLUMN IF NOT EXISTS event_at TIMESTAMPTZ;

CREATE TABLE IF NOT EXISTS public.group_pick_rankings (
    pick_id   UUID NOT NULL REFERENCES public.group_picks(id) ON DELETE CASCADE,
    user_id   TEXT NOT NULL,
    place_id  TEXT NOT NULL,
    rank      SMALLINT NOT NULL CHECK (rank BETWEEN 1 AND 3),
    ranked_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_group_pick_rank_slot  ON public.group_pick_rankings (pick_id, lower(user_id), rank);
CREATE UNIQUE INDEX IF NOT EXISTS uq_group_pick_rank_place ON public.group_pick_rankings (pick_id, lower(user_id), place_id);
ALTER TABLE public.group_pick_rankings ENABLE ROW LEVEL SECURITY;  -- RPC-only access, no policies
REVOKE ALL ON public.group_pick_rankings FROM anon, authenticated;

-- ---------------------------------------------------------------- standings
CREATE OR REPLACE FUNCTION public._group_pick_borda(p_pick_id UUID)
RETURNS TABLE(pid TEXT, ord BIGINT, points BIGINT, first_n BIGINT, second_n BIGINT, third_n BIGINT, voters BIGINT)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
    SELECT p.place_id, p.ord,
           COALESCE(SUM(4 - r.rank), 0),
           COUNT(*) FILTER (WHERE r.rank = 1),
           COUNT(*) FILTER (WHERE r.rank = 2),
           COUNT(*) FILTER (WHERE r.rank = 3),
           COUNT(r.user_id)
    FROM group_picks g
    CROSS JOIN LATERAL unnest(g.place_ids) WITH ORDINALITY AS p(place_id, ord)
    LEFT JOIN group_pick_rankings r ON r.pick_id = g.id AND r.place_id = p.place_id
    WHERE g.id = p_pick_id
    GROUP BY p.place_id, p.ord
    ORDER BY 3 DESC, 4 DESC, 5 DESC, 2 ASC;
$$;

CREATE OR REPLACE FUNCTION public._planned_group_pick_json(p_pick_id UUID)
RETURNS JSON LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
    SELECT json_build_object(
        'id', g.id, 'creator_id', g.creator_id, 'title', g.title, 'place_ids', g.place_ids,
        'mode', g.mode, 'event_at', g.event_at, 'decide_at', g.decide_at,
        'decided_place_id', g.decided_place_id, 'decided_at', g.decided_at, 'outcome', g.outcome,
        'member_count', (SELECT COUNT(*) FROM group_pick_members m WHERE m.pick_id = g.id),
        'ranked_count', (SELECT COUNT(DISTINCT lower(r.user_id)) FROM group_pick_rankings r WHERE r.pick_id = g.id),
        'standings', COALESCE((SELECT json_agg(json_build_object(
                'place_id', b.pid, 'points', b.points, 'first', b.first_n,
                'second', b.second_n, 'third', b.third_n, 'voters', b.voters))
            FROM _group_pick_borda(g.id) b), '[]'::json),
        'my_ranking', COALESCE((SELECT json_agg(r.place_id ORDER BY r.rank) FROM group_pick_rankings r
            WHERE r.pick_id = g.id AND lower(r.user_id) = lower(app_uid())), '[]'::json)
    )
    FROM group_picks g WHERE g.id = p_pick_id;
$$;

-- ---------------------------------------------------------------- decision
CREATE OR REPLACE FUNCTION public._maybe_decide_planned_group_pick(p_pick_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    v_pick group_picks%ROWTYPE; v_members INT; v_ranked INT; v_reason TEXT;
    v_top RECORD; v_second RECORD; v_outcome TEXT; v_winner TEXT; v_name TEXT;
    v_top3 JSONB; v_member RECORD;
BEGIN
    SELECT * INTO v_pick FROM group_picks WHERE id = p_pick_id FOR UPDATE;
    IF NOT FOUND OR v_pick.decided_at IS NOT NULL OR v_pick.mode <> 'planned' THEN RETURN; END IF;

    SELECT COUNT(*) INTO v_members FROM group_pick_members WHERE pick_id = p_pick_id;
    SELECT COUNT(DISTINCT lower(user_id)) INTO v_ranked FROM group_pick_rankings WHERE pick_id = p_pick_id;

    IF now() >= v_pick.decide_at THEN v_reason := 'deadline';
    ELSIF v_members >= 2 AND v_ranked >= v_members THEN v_reason := 'everyone_voted';
    ELSE RETURN; END IF;

    SELECT * INTO v_top    FROM _group_pick_borda(p_pick_id) LIMIT 1;
    SELECT * INTO v_second FROM _group_pick_borda(p_pick_id) OFFSET 1 LIMIT 1;

    IF v_top.pid IS NULL OR v_top.points = 0 THEN
        v_outcome := 'no_match'; v_winner := NULL;
    ELSE
        v_winner := v_top.pid;
        v_outcome := CASE WHEN v_second.pid IS NOT NULL AND v_second.points = v_top.points
                          THEN 'tie_break' ELSE 'winner' END;
    END IF;

    UPDATE group_picks SET decided_place_id = v_winner, decided_at = now(),
           outcome = v_outcome, decided_reason = v_reason
    WHERE id = p_pick_id;

    IF v_winner IS NOT NULL THEN SELECT name INTO v_name FROM places WHERE id = v_winner; END IF;
    SELECT COALESCE(jsonb_agg(jsonb_build_object('place_id', b.pid, 'name', pl.name, 'points', b.points)), '[]'::jsonb)
      INTO v_top3
      FROM (SELECT * FROM _group_pick_borda(p_pick_id) WHERE points > 0 LIMIT 3) b
      LEFT JOIN places pl ON pl.id = b.pid;

    FOR v_member IN SELECT user_id FROM group_pick_members WHERE pick_id = p_pick_id LOOP
        PERFORM _push_group_pick(v_member.user_id, jsonb_build_object(
            'type', 'group_pick_decided', 'mode', 'planned',
            'pick_id', p_pick_id, 'pick_title', v_pick.title, 'event_at', v_pick.event_at,
            'place_id', v_winner, 'place_name', v_name, 'outcome', v_outcome,
            'top3', v_top3, 'yes_count', v_ranked, 'member_count', v_members));
    END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public._maybe_decide_group_pick(p_pick_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    v_pick    group_picks%ROWTYPE;
    v_members INT;
    v_pending INT;
    v_top     RECORD;
    v_second  RECORD;
    v_reason  TEXT;
    v_outcome TEXT;
    v_winner  TEXT;
    v_name    TEXT;
    v_member  RECORD;
BEGIN
    SELECT * INTO v_pick FROM group_picks WHERE id = p_pick_id FOR UPDATE;
    IF NOT FOUND OR v_pick.decided_at IS NOT NULL THEN RETURN; END IF;
    -- Planned (ranked) picks use Borda rules, never the yes/no rules below.
    IF v_pick.mode = 'planned' THEN PERFORM _maybe_decide_planned_group_pick(p_pick_id); RETURN; END IF;

    SELECT COUNT(*) INTO v_members FROM group_pick_members WHERE pick_id = p_pick_id;
    SELECT COUNT(*) INTO v_pending FROM _group_pick_pending_members(p_pick_id);

    SELECT * INTO v_top FROM _group_pick_standings(p_pick_id)
        ORDER BY yes_n DESC, no_n ASC, ord ASC LIMIT 1;
    SELECT * INTO v_second FROM _group_pick_standings(p_pick_id)
        ORDER BY yes_n DESC, no_n ASC, ord ASC OFFSET 1 LIMIT 1;

    IF v_members >= 2 AND v_pending = 0 THEN
        v_reason := 'everyone_voted';
    ELSIF now() >= v_pick.decide_at THEN
        v_reason := 'timeout';
    ELSIF v_members >= 2 AND v_top.yes_n = v_members THEN
        -- Everyone said yes to the same place: that's a match, decide now even if other places are unvoted.
        v_reason := 'unanimous';
    ELSIF v_members >= 2 AND v_top.yes_n * 2 > v_members
          AND NOT EXISTS (SELECT 1 FROM _group_pick_standings(p_pick_id) q
                          WHERE q.pid <> v_top.pid AND q.yes_n + q.unvoted_n >= v_top.yes_n) THEN
        v_reason := 'clear_winner';
    ELSE
        RETURN;
    END IF;

    IF v_top.pid IS NULL OR v_top.yes_n = 0 THEN
        v_outcome := 'no_match';
        v_winner := NULL;
    ELSE
        v_winner := v_top.pid;
        v_outcome := CASE WHEN v_second.pid IS NOT NULL AND v_second.yes_n = v_top.yes_n AND v_second.no_n = v_top.no_n
                          THEN 'tie_break' ELSE 'winner' END;
    END IF;

    UPDATE group_picks
    SET decided_place_id = v_winner, decided_at = now(), outcome = v_outcome, decided_reason = v_reason
    WHERE id = p_pick_id;

    IF v_winner IS NOT NULL THEN SELECT name INTO v_name FROM places WHERE id = v_winner; END IF;

    FOR v_member IN SELECT user_id FROM group_pick_members WHERE pick_id = p_pick_id LOOP
        PERFORM _push_group_pick(v_member.user_id, jsonb_build_object(
            'type', 'group_pick_decided',
            'pick_id', p_pick_id,
            'pick_title', v_pick.title,
            'place_id', v_winner,
            'place_name', v_name,
            'outcome', v_outcome,
            'yes_count', COALESCE(v_top.yes_n, 0),
            'member_count', v_members));
    END LOOP;
END $$;

-- ---------------------------------------------------------------- RPCs
-- p_decide_at NULL => day before the event (or +24h without an event), clamped to [now+15m, event_at].
CREATE OR REPLACE FUNCTION public.create_planned_group_pick(
    p_place_ids TEXT[], p_title TEXT DEFAULT NULL,
    p_event_at TIMESTAMPTZ DEFAULT NULL, p_decide_at TIMESTAMPTZ DEFAULT NULL)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_me TEXT := app_uid(); v_id UUID; v_deadline TIMESTAMPTZ;
BEGIN
    IF v_me IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
    IF p_event_at IS NOT NULL AND p_event_at < now() THEN RAISE EXCEPTION 'event is in the past'; END IF;
    v_deadline := COALESCE(p_decide_at, p_event_at - interval '1 day', now() + interval '24 hours');
    IF p_event_at IS NOT NULL THEN v_deadline := LEAST(v_deadline, p_event_at); END IF;
    v_deadline := GREATEST(v_deadline, now() + interval '15 minutes');
    v_deadline := LEAST(v_deadline, now() + interval '60 days');
    INSERT INTO group_picks (creator_id, title, place_ids, decide_at, mode, event_at)
    VALUES (v_me, p_title, p_place_ids, v_deadline, 'planned', p_event_at)
    RETURNING id INTO v_id;
    INSERT INTO group_pick_members (pick_id, user_id) VALUES (v_id, v_me);
    RETURN v_id;
END $$;

-- Replaces the caller's ranking (ordered, up to 3 distinct places in the pick). Empty array clears it.
CREATE OR REPLACE FUNCTION public.rank_group_pick(p_pick_id UUID, p_place_ids TEXT[])
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_me TEXT := app_uid(); v_pick group_picks%ROWTYPE; v_pid TEXT; v_rank INT := 0;
BEGIN
    IF v_me IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
    SELECT * INTO v_pick FROM group_picks WHERE id = p_pick_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'pick not found'; END IF;
    IF v_pick.mode <> 'planned' THEN RAISE EXCEPTION 'not a ranked pick'; END IF;
    IF v_pick.decided_at IS NULL AND now() < v_pick.decide_at THEN
        INSERT INTO group_pick_members (pick_id, user_id)
        SELECT p_pick_id, v_me
        WHERE NOT EXISTS (SELECT 1 FROM group_pick_members WHERE pick_id = p_pick_id AND lower(user_id) = lower(v_me));
        DELETE FROM group_pick_rankings WHERE pick_id = p_pick_id AND lower(user_id) = lower(v_me);
        FOREACH v_pid IN ARRAY COALESCE(p_place_ids, ARRAY[]::TEXT[]) LOOP
            CONTINUE WHEN NOT (v_pid = ANY (v_pick.place_ids));
            CONTINUE WHEN EXISTS (SELECT 1 FROM group_pick_rankings WHERE pick_id = p_pick_id
                                  AND lower(user_id) = lower(v_me) AND place_id = v_pid);
            v_rank := v_rank + 1;
            EXIT WHEN v_rank > 3;
            INSERT INTO group_pick_rankings (pick_id, user_id, place_id, rank) VALUES (p_pick_id, v_me, v_pid, v_rank);
        END LOOP;
    END IF;
    PERFORM _maybe_decide_group_pick(p_pick_id);
    RETURN _planned_group_pick_json(p_pick_id);
END $$;

-- Joins (if open) and returns the ranked state. Same join semantics as get_group_pick.
CREATE OR REPLACE FUNCTION public.get_planned_group_pick(p_pick_id UUID)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_me TEXT := app_uid();
BEGIN
    IF v_me IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
    IF NOT EXISTS (SELECT 1 FROM group_picks WHERE id = p_pick_id) THEN RETURN NULL; END IF;
    INSERT INTO group_pick_members (pick_id, user_id)
    SELECT p_pick_id, v_me
    WHERE NOT EXISTS (SELECT 1 FROM group_pick_members WHERE pick_id = p_pick_id AND lower(user_id) = lower(v_me))
      AND (SELECT decided_at FROM group_picks WHERE id = p_pick_id) IS NULL;
    PERFORM _maybe_decide_group_pick(p_pick_id);
    RETURN _planned_group_pick_json(p_pick_id);
END $$;

REVOKE ALL ON FUNCTION public._group_pick_borda(UUID)                  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._planned_group_pick_json(UUID)           FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._maybe_decide_planned_group_pick(UUID)   FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._maybe_decide_group_pick(UUID)           FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.create_planned_group_pick(TEXT[], TEXT, TIMESTAMPTZ, TIMESTAMPTZ) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.rank_group_pick(UUID, TEXT[])            FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_planned_group_pick(UUID)             FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_planned_group_pick(TEXT[], TEXT, TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rank_group_pick(UUID, TEXT[])         TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_planned_group_pick(UUID)          TO authenticated;
