-- ============================================================================
-- Migration: Tonight + Group Picks   (applied to posfruqvibklcyfxmdbq 2026-10-26, approved by Drew)
-- ============================================================================
-- Creates:
--   * group_picks         one row per "where should we go?" poll (places pre-filled)
--   * group_pick_members  who is in the poll (creator + anyone who opened the link)
--   * group_pick_votes    one yes/no per (pick, user, place)
--   * RLS enabled on all three; members can read, users can only write their own rows
--   * RPCs (SECURITY DEFINER, authenticated only):
--       create_group_pick(p_place_ids text[], p_title text, p_minutes int) -> uuid
--       get_group_pick(p_pick_id uuid)       -> json (joins caller, auto-decides if due)
--       vote_group_pick(p_pick_id, p_place_id, p_vote) -> json (same shape)
--       get_tonight_candidates(p_user_ids text[]) -> place ids + who saved them
--         (lets Tonight see friends' favorites / TikTok saves, which RLS hides
--          from the client today; the app falls back to own saves + friends'
--          public lists if this function is missing)
-- Auto-decision: a pick is decided as soon as every member (>= 2) has voted on
-- every place, or when decide_at passes (checked lazily on every read/vote).
-- Winner = most yes votes, then fewest no votes, then original order.
-- User ids are TEXT with mixed case: all comparisons use lower(); identity
-- comes from public.app_uid().
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.group_picks (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    creator_id       TEXT NOT NULL,
    title            TEXT,
    place_ids        TEXT[] NOT NULL CHECK (cardinality(place_ids) BETWEEN 1 AND 10),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    decide_at        TIMESTAMPTZ NOT NULL DEFAULT now() + interval '90 minutes',
    decided_place_id TEXT,
    decided_at       TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.group_pick_members (
    pick_id   UUID NOT NULL REFERENCES public.group_picks(id) ON DELETE CASCADE,
    user_id   TEXT NOT NULL,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (pick_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.group_pick_votes (
    pick_id    UUID NOT NULL REFERENCES public.group_picks(id) ON DELETE CASCADE,
    user_id    TEXT NOT NULL,
    place_id   TEXT NOT NULL,
    vote       BOOLEAN NOT NULL,
    voted_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (pick_id, user_id, place_id)
);

CREATE INDEX IF NOT EXISTS idx_group_picks_creator ON public.group_picks (lower(creator_id));
CREATE INDEX IF NOT EXISTS idx_group_pick_members_user ON public.group_pick_members (lower(user_id));
-- user ids are mixed-case text: enforce one membership / one vote per place case-insensitively
CREATE UNIQUE INDEX IF NOT EXISTS uq_group_pick_members_lower ON public.group_pick_members (pick_id, lower(user_id));
CREATE UNIQUE INDEX IF NOT EXISTS uq_group_pick_votes_lower ON public.group_pick_votes (pick_id, lower(user_id), place_id);

-- ---------------------------------------------------------------- RLS
ALTER TABLE public.group_picks        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_pick_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_pick_votes   ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.group_picks, public.group_pick_members, public.group_pick_votes FROM anon;

CREATE OR REPLACE FUNCTION public.is_group_pick_member(p_pick_id UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
    SELECT EXISTS (SELECT 1 FROM group_pick_members
                   WHERE pick_id = p_pick_id AND lower(user_id) = lower(app_uid()));
$$;

CREATE POLICY group_picks_select ON public.group_picks FOR SELECT TO authenticated
    USING (lower(creator_id) = lower(app_uid()) OR public.is_group_pick_member(id));
CREATE POLICY group_picks_insert ON public.group_picks FOR INSERT TO authenticated
    WITH CHECK (lower(creator_id) = lower(app_uid()));

CREATE POLICY group_pick_members_select ON public.group_pick_members FOR SELECT TO authenticated
    USING (public.is_group_pick_member(pick_id));
CREATE POLICY group_pick_members_insert ON public.group_pick_members FOR INSERT TO authenticated
    WITH CHECK (lower(user_id) = lower(app_uid()));

CREATE POLICY group_pick_votes_select ON public.group_pick_votes FOR SELECT TO authenticated
    USING (public.is_group_pick_member(pick_id));
CREATE POLICY group_pick_votes_insert ON public.group_pick_votes FOR INSERT TO authenticated
    WITH CHECK (lower(user_id) = lower(app_uid()) AND public.is_group_pick_member(pick_id));
CREATE POLICY group_pick_votes_update ON public.group_pick_votes FOR UPDATE TO authenticated
    USING (lower(user_id) = lower(app_uid()))
    WITH CHECK (lower(user_id) = lower(app_uid()));

-- ---------------------------------------------------------------- RPCs
CREATE OR REPLACE FUNCTION public.create_group_pick(p_place_ids TEXT[], p_title TEXT DEFAULT NULL, p_minutes INT DEFAULT 90)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_me TEXT := app_uid(); v_id UUID;
BEGIN
    IF v_me IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
    INSERT INTO group_picks (creator_id, title, place_ids, decide_at)
    VALUES (v_me, p_title, p_place_ids, now() + make_interval(mins => GREATEST(10, LEAST(COALESCE(p_minutes, 90), 1440))))
    RETURNING id INTO v_id;
    INSERT INTO group_pick_members (pick_id, user_id) VALUES (v_id, v_me);
    RETURN v_id;
END $$;

-- Decides the pick if everyone has voted on everything or time is up. Internal.
CREATE OR REPLACE FUNCTION public._maybe_decide_group_pick(p_pick_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_pick group_picks%ROWTYPE; v_members INT; v_complete INT; v_winner TEXT;
BEGIN
    SELECT * INTO v_pick FROM group_picks WHERE id = p_pick_id FOR UPDATE;
    IF NOT FOUND OR v_pick.decided_at IS NOT NULL THEN RETURN; END IF;

    SELECT COUNT(*) INTO v_members FROM group_pick_members WHERE pick_id = p_pick_id;
    SELECT COUNT(*) INTO v_complete FROM (
        SELECT lower(user_id) FROM group_pick_votes
        WHERE pick_id = p_pick_id AND place_id = ANY (v_pick.place_ids)
        GROUP BY lower(user_id)
        HAVING COUNT(DISTINCT place_id) >= cardinality(v_pick.place_ids)
    ) c;

    IF NOT ((v_members >= 2 AND v_complete >= v_members) OR now() >= v_pick.decide_at) THEN
        RETURN;
    END IF;

    SELECT p.place_id INTO v_winner
    FROM unnest(v_pick.place_ids) WITH ORDINALITY AS p(place_id, ord)
    LEFT JOIN group_pick_votes v ON v.pick_id = p_pick_id AND v.place_id = p.place_id
    GROUP BY p.place_id, p.ord
    ORDER BY COUNT(*) FILTER (WHERE v.vote) DESC,
             COUNT(*) FILTER (WHERE v.vote = false) ASC,
             p.ord ASC
    LIMIT 1;

    UPDATE group_picks SET decided_place_id = v_winner, decided_at = now() WHERE id = p_pick_id;
END $$;

-- Returns the pick state as JSON for the caller.
CREATE OR REPLACE FUNCTION public._group_pick_json(p_pick_id UUID)
RETURNS JSON LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
    SELECT json_build_object(
        'id', g.id,
        'creator_id', g.creator_id,
        'title', g.title,
        'place_ids', g.place_ids,
        'decide_at', g.decide_at,
        'decided_place_id', g.decided_place_id,
        'decided_at', g.decided_at,
        'member_count', (SELECT COUNT(*) FROM group_pick_members m WHERE m.pick_id = g.id),
        'tallies', COALESCE((
            SELECT json_agg(json_build_object(
                'place_id', p.place_id,
                'yes', (SELECT COUNT(*) FROM group_pick_votes v WHERE v.pick_id = g.id AND v.place_id = p.place_id AND v.vote),
                'no',  (SELECT COUNT(*) FROM group_pick_votes v WHERE v.pick_id = g.id AND v.place_id = p.place_id AND NOT v.vote)
            ) ORDER BY p.ord)
            FROM unnest(g.place_ids) WITH ORDINALITY AS p(place_id, ord)), '[]'::json),
        'my_votes', COALESCE((
            SELECT json_object_agg(v.place_id, v.vote) FROM group_pick_votes v
            WHERE v.pick_id = g.id AND lower(v.user_id) = lower(app_uid())), '{}'::json)
    )
    FROM group_picks g WHERE g.id = p_pick_id;
$$;

CREATE OR REPLACE FUNCTION public.get_group_pick(p_pick_id UUID)
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
    RETURN _group_pick_json(p_pick_id);
END $$;

CREATE OR REPLACE FUNCTION public.vote_group_pick(p_pick_id UUID, p_place_id TEXT, p_vote BOOLEAN)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_me TEXT := app_uid(); v_pick group_picks%ROWTYPE;
BEGIN
    IF v_me IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
    SELECT * INTO v_pick FROM group_picks WHERE id = p_pick_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'pick not found'; END IF;
    IF v_pick.decided_at IS NULL AND p_place_id = ANY (v_pick.place_ids) THEN
        INSERT INTO group_pick_members (pick_id, user_id)
        SELECT p_pick_id, v_me
        WHERE NOT EXISTS (SELECT 1 FROM group_pick_members WHERE pick_id = p_pick_id AND lower(user_id) = lower(v_me));
        DELETE FROM group_pick_votes WHERE pick_id = p_pick_id AND place_id = p_place_id AND lower(user_id) = lower(v_me);
        INSERT INTO group_pick_votes (pick_id, user_id, place_id, vote) VALUES (p_pick_id, v_me, p_place_id, p_vote);
    END IF;
    PERFORM _maybe_decide_group_pick(p_pick_id);
    RETURN _group_pick_json(p_pick_id);
END $$;

-- Tonight candidates: every place saved (favorites, my_places, TikTok imports,
-- own lists, others' public lists) by the caller or by people the caller follows.
CREATE OR REPLACE FUNCTION public.get_tonight_candidates(p_user_ids TEXT[])
RETURNS TABLE(place_id TEXT, saver_ids TEXT[])
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
    WITH me AS (SELECT lower(app_uid()) AS uid),
    allowed AS (
        SELECT uid FROM me
        UNION
        SELECT lower(f.following_id) FROM following f, me
        WHERE lower(f.follower_id) = me.uid
          AND lower(f.following_id) IN (SELECT lower(x) FROM unnest(p_user_ids) x)
    ),
    s AS (
        SELECT lower(user_id) AS uid, place_id FROM favorites       WHERE lower(user_id) IN (SELECT uid FROM allowed)
        UNION ALL SELECT lower(user_id), place_id FROM my_places     WHERE lower(user_id) IN (SELECT uid FROM allowed)
        UNION ALL SELECT lower(user_id), place_id FROM external_places WHERE lower(user_id) IN (SELECT uid FROM allowed)
        UNION ALL
        SELECT lower(pl.user_id), pli.place_id FROM place_lists pl JOIN place_list_items pli ON pli.list_id = pl.id, me
        WHERE lower(pl.user_id) IN (SELECT uid FROM allowed)
          AND (lower(pl.user_id) = me.uid OR COALESCE(pl.is_public, true))
    )
    SELECT place_id, array_agg(DISTINCT uid) FROM s WHERE place_id IS NOT NULL GROUP BY place_id;
$$;

REVOKE ALL ON FUNCTION public.create_group_pick(TEXT[], TEXT, INT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_group_pick(UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.vote_group_pick(UUID, TEXT, BOOLEAN) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_tonight_candidates(TEXT[]) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public._maybe_decide_group_pick(UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._group_pick_json(UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.is_group_pick_member(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_group_pick(TEXT[], TEXT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_group_pick(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.vote_group_pick(UUID, TEXT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_tonight_candidates(TEXT[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_group_pick_member(UUID) TO authenticated;
