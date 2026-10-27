-- ============================================================================
-- Migration: Group pick resolution, push notifications, more options
--            *** NOT APPLIED — needs Drew's approval before it touches posfruqvibklcyfxmdbq ***
-- ============================================================================
-- Builds on 20261026_tonight_group_picks.sql (already applied).
--
-- Fixes "we both voted and nothing happened, nobody was told":
--   * Decision rules (checked on every vote / read AND by a pg_cron job every minute,
--     so the 90-minute timer resolves with nobody in the app):
--       1. everyone_voted  every member (>= 2) voted on every place
--       2. unanimous       every member (>= 2) said yes to the same place and no better-ranked
--                          place could still end up unanimous
--       3. clear_winner    a strict majority said yes to one place and no other place can
--                          even tie it, whatever the missing votes turn out to be
--       4. timeout         decide_at passed
--   * Winner = most yes, then fewest no, then original (Tonight rank) order.
--     outcome = 'winner' | 'tie_break' (top places level on yes AND no; rank order broke it)
--             | 'no_match' (nobody said yes to anything: pick is closed without a winner,
--               and any member can add more options to reopen it)
--   * On decision every member gets a push (type group_pick_decided).
--   * Members also get a push when they are invited (group_pick_invited), when a pick is
--     waiting only on them (group_pick_waiting) and when options are added (group_pick_options).
--     Pushes go to the send-push-notification edge function through pg_net, fire-and-forget:
--     if the function is not deployed (or does not know the type) nothing breaks.
--
-- New / changed objects (all additive; old clients keep working because the JSON only gains keys):
--   columns   group_picks.outcome, decided_reason, added_by, last_nudged_user; group_pick_members.invited_by
--   internal  _push_group_pick, _group_pick_standings, _group_pick_pending_members,
--             _maybe_decide_group_pick (replaced), _group_pick_json (replaced), resolve_due_group_picks
--   RPCs      vote_group_pick (replaced), invite_group_pick_members, add_group_pick_places, my_group_picks
--   cron      resolve-group-picks (every minute; skipped if pg_cron is not installed)
-- ============================================================================

ALTER TABLE public.group_picks
    ADD COLUMN IF NOT EXISTS outcome          TEXT CHECK (outcome IN ('winner', 'tie_break', 'no_match')),
    ADD COLUMN IF NOT EXISTS decided_reason   TEXT,
    ADD COLUMN IF NOT EXISTS added_by         JSONB NOT NULL DEFAULT '{}'::jsonb,   -- place_id -> user who added it
    ADD COLUMN IF NOT EXISTS last_nudged_user TEXT;                                  -- avoids repeating the "waiting on you" push

ALTER TABLE public.group_pick_members
    ADD COLUMN IF NOT EXISTS invited_by TEXT;

UPDATE public.group_picks SET outcome = 'winner'
WHERE decided_at IS NOT NULL AND decided_place_id IS NOT NULL AND outcome IS NULL;

-- ---------------------------------------------------------------- push helper
-- Sends one push through the send-push-notification edge function. Never raises.
-- The function is deployed with verify_jwt = false (same as the user_notifications trigger path).
CREATE OR REPLACE FUNCTION public._push_group_pick(p_user_id TEXT, p_payload JSONB)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
    IF p_user_id IS NULL THEN RETURN; END IF;
    PERFORM net.http_post(
        url     := 'https://posfruqvibklcyfxmdbq.supabase.co/functions/v1/send-push-notification',
        body    := jsonb_build_object('record', p_payload || jsonb_build_object('user_id', p_user_id)),
        headers := jsonb_build_object('Content-Type', 'application/json')
    );
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'group pick push failed: %', SQLERRM;
END $$;

-- ---------------------------------------------------------------- standings
-- One row per place in the pick with yes/no counts and how many members have not voted on it.
CREATE OR REPLACE FUNCTION public._group_pick_standings(p_pick_id UUID)
RETURNS TABLE(pid TEXT, ord BIGINT, yes_n BIGINT, no_n BIGINT, voted_n BIGINT, unvoted_n BIGINT)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
    SELECT p.place_id,
           p.ord,
           COUNT(*) FILTER (WHERE v.vote),
           COUNT(*) FILTER (WHERE v.vote = false),
           COUNT(v.user_id),
           GREATEST((SELECT COUNT(*) FROM group_pick_members m WHERE m.pick_id = p_pick_id) - COUNT(v.user_id), 0)
    FROM group_picks g
    CROSS JOIN LATERAL unnest(g.place_ids) WITH ORDINALITY AS p(place_id, ord)
    LEFT JOIN group_pick_votes v ON v.pick_id = g.id AND v.place_id = p.place_id
    WHERE g.id = p_pick_id
    GROUP BY p.place_id, p.ord;
$$;

-- Members who have not voted on every place yet.
CREATE OR REPLACE FUNCTION public._group_pick_pending_members(p_pick_id UUID)
RETURNS SETOF TEXT LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
    SELECT m.user_id
    FROM group_pick_members m
    JOIN group_picks g ON g.id = m.pick_id
    WHERE m.pick_id = p_pick_id
      AND (SELECT COUNT(DISTINCT v.place_id) FROM group_pick_votes v
           WHERE v.pick_id = m.pick_id AND lower(v.user_id) = lower(m.user_id)
             AND v.place_id = ANY (g.place_ids)) < cardinality(g.place_ids)
    ORDER BY m.joined_at;
$$;

-- ---------------------------------------------------------------- decision
-- Decides the pick if a rule fires, records the outcome and pushes every member. Internal.
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
    ELSIF v_members >= 2 AND v_top.yes_n = v_members
          AND NOT EXISTS (SELECT 1 FROM _group_pick_standings(p_pick_id) q
                          WHERE q.pid <> v_top.pid AND q.ord < v_top.ord AND q.no_n = 0) THEN
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

-- Sends the "waiting only on you" push once per person per pick.
CREATE OR REPLACE FUNCTION public._nudge_last_group_pick_voter(p_pick_id UUID, p_actor TEXT)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_pick group_picks%ROWTYPE; v_pending TEXT[]; v_members INT; v_actor_name TEXT;
BEGIN
    SELECT * INTO v_pick FROM group_picks WHERE id = p_pick_id;
    IF NOT FOUND OR v_pick.decided_at IS NOT NULL THEN RETURN; END IF;
    SELECT COUNT(*) INTO v_members FROM group_pick_members WHERE pick_id = p_pick_id;
    SELECT array_agg(x) INTO v_pending FROM _group_pick_pending_members(p_pick_id) x;
    IF v_members >= 2 AND cardinality(v_pending) = 1
       AND lower(v_pending[1]) <> lower(p_actor)
       AND (v_pick.last_nudged_user IS NULL OR lower(v_pick.last_nudged_user) <> lower(v_pending[1])) THEN
        UPDATE group_picks SET last_nudged_user = v_pending[1] WHERE id = p_pick_id;
        SELECT first_name INTO v_actor_name FROM users WHERE lower(id) = lower(p_actor);
        PERFORM _push_group_pick(v_pending[1], jsonb_build_object(
            'type', 'group_pick_waiting',
            'pick_id', p_pick_id,
            'pick_title', v_pick.title,
            'actor_id', p_actor,
            'actor_first_name', v_actor_name,
            'member_count', v_members));
    END IF;
END $$;

-- ---------------------------------------------------------------- JSON
-- Pick state for the caller. Adds outcome, who voted how, who is still pending, who added which place.
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
        'outcome', g.outcome,
        'decided_reason', g.decided_reason,
        'added_by', g.added_by,
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
            WHERE v.pick_id = g.id AND lower(v.user_id) = lower(app_uid())), '{}'::json),
        'members', COALESCE((
            SELECT json_agg(json_build_object(
                'user_id', m.user_id,
                'first_name', u.first_name,
                'last_name', u.last_name,
                'voted_count', (SELECT COUNT(DISTINCT v.place_id) FROM group_pick_votes v
                                WHERE v.pick_id = g.id AND lower(v.user_id) = lower(m.user_id) AND v.place_id = ANY (g.place_ids)),
                'votes', COALESCE((SELECT json_object_agg(v.place_id, v.vote) FROM group_pick_votes v
                                   WHERE v.pick_id = g.id AND lower(v.user_id) = lower(m.user_id)), '{}'::json)
            ) ORDER BY m.joined_at)
            FROM group_pick_members m
            LEFT JOIN users u ON lower(u.id) = lower(m.user_id)
            WHERE m.pick_id = g.id), '[]'::json),
        'waiting_on', COALESCE((SELECT json_agg(w) FROM _group_pick_pending_members(g.id) w), '[]'::json)
    )
    FROM group_picks g WHERE g.id = p_pick_id;
$$;

-- ---------------------------------------------------------------- RPCs
-- Replaces the 20261026 version: same behaviour plus the "waiting only on you" nudge.
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
    PERFORM _nudge_last_group_pick_voter(p_pick_id, v_me);
    RETURN _group_pick_json(p_pick_id);
END $$;

-- Adds people to an undecided pick (max 12 members). Only people the caller follows / is followed by.
-- Each newly added person gets a push.
CREATE OR REPLACE FUNCTION public.invite_group_pick_members(p_pick_id UUID, p_user_ids TEXT[])
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    v_me TEXT := app_uid(); v_pick group_picks%ROWTYPE; v_uid TEXT; v_target TEXT;
    v_count INT; v_actor_name TEXT;
BEGIN
    IF v_me IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
    SELECT * INTO v_pick FROM group_picks WHERE id = p_pick_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'pick not found'; END IF;
    IF NOT EXISTS (SELECT 1 FROM group_pick_members WHERE pick_id = p_pick_id AND lower(user_id) = lower(v_me)) THEN
        RAISE EXCEPTION 'not a member of this pick';
    END IF;
    IF v_pick.decided_at IS NOT NULL THEN RETURN _group_pick_json(p_pick_id); END IF;

    SELECT first_name INTO v_actor_name FROM users WHERE lower(id) = lower(v_me);
    FOREACH v_uid IN ARRAY COALESCE(p_user_ids, ARRAY[]::TEXT[]) LOOP
        SELECT id INTO v_target FROM users WHERE lower(id) = lower(v_uid);
        CONTINUE WHEN v_target IS NULL;
        CONTINUE WHEN EXISTS (SELECT 1 FROM group_pick_members WHERE pick_id = p_pick_id AND lower(user_id) = lower(v_target));
        CONTINUE WHEN NOT EXISTS (
            SELECT 1 FROM following f
            WHERE (lower(f.follower_id) = lower(v_me) AND lower(f.following_id) = lower(v_target))
               OR (lower(f.follower_id) = lower(v_target) AND lower(f.following_id) = lower(v_me)));
        SELECT COUNT(*) INTO v_count FROM group_pick_members WHERE pick_id = p_pick_id;
        EXIT WHEN v_count >= 12;
        INSERT INTO group_pick_members (pick_id, user_id, invited_by) VALUES (p_pick_id, v_target, v_me);
        PERFORM _push_group_pick(v_target, jsonb_build_object(
            'type', 'group_pick_invited',
            'pick_id', p_pick_id,
            'pick_title', v_pick.title,
            'actor_id', v_me,
            'actor_first_name', v_actor_name));
    END LOOP;
    RETURN _group_pick_json(p_pick_id);
END $$;

-- Adds places to the vote (max 10 total). Allowed while undecided, or after a 'no_match' result
-- (that reopens the pick for at least 30 more minutes). Places must exist in public.places.
-- Other members get a push.
CREATE OR REPLACE FUNCTION public.add_group_pick_places(p_pick_id UUID, p_place_ids TEXT[])
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    v_me TEXT := app_uid(); v_pick group_picks%ROWTYPE; v_pid TEXT; v_added INT := 0;
    v_ids TEXT[]; v_by JSONB; v_actor_name TEXT; v_member RECORD;
BEGIN
    IF v_me IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
    SELECT * INTO v_pick FROM group_picks WHERE id = p_pick_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'pick not found'; END IF;
    IF NOT EXISTS (SELECT 1 FROM group_pick_members WHERE pick_id = p_pick_id AND lower(user_id) = lower(v_me)) THEN
        RAISE EXCEPTION 'not a member of this pick';
    END IF;
    IF v_pick.decided_at IS NOT NULL AND v_pick.outcome IS DISTINCT FROM 'no_match' THEN
        RETURN _group_pick_json(p_pick_id);
    END IF;

    v_ids := v_pick.place_ids;
    v_by  := v_pick.added_by;
    FOREACH v_pid IN ARRAY COALESCE(p_place_ids, ARRAY[]::TEXT[]) LOOP
        EXIT WHEN cardinality(v_ids) >= 10;
        CONTINUE WHEN v_pid = ANY (v_ids);
        CONTINUE WHEN NOT EXISTS (SELECT 1 FROM places WHERE id = v_pid);
        v_ids := v_ids || v_pid;
        v_by  := v_by || jsonb_build_object(v_pid, v_me);
        v_added := v_added + 1;
    END LOOP;
    IF v_added = 0 THEN RETURN _group_pick_json(p_pick_id); END IF;

    UPDATE group_picks
    SET place_ids = v_ids,
        added_by = v_by,
        decided_place_id = NULL, decided_at = NULL, outcome = NULL, decided_reason = NULL, last_nudged_user = NULL,
        decide_at = CASE WHEN v_pick.decided_at IS NOT NULL THEN GREATEST(v_pick.decide_at, now() + interval '30 minutes')
                         ELSE v_pick.decide_at END
    WHERE id = p_pick_id;

    SELECT first_name INTO v_actor_name FROM users WHERE lower(id) = lower(v_me);
    FOR v_member IN SELECT user_id FROM group_pick_members
                    WHERE pick_id = p_pick_id AND lower(user_id) <> lower(v_me) LOOP
        PERFORM _push_group_pick(v_member.user_id, jsonb_build_object(
            'type', 'group_pick_options',
            'pick_id', p_pick_id,
            'pick_title', v_pick.title,
            'actor_id', v_me,
            'actor_first_name', v_actor_name,
            'added_count', v_added));
    END LOOP;
    RETURN _group_pick_json(p_pick_id);
END $$;

-- The caller's active picks and picks decided in the last 24 hours (Tonight's "your picks" row).
CREATE OR REPLACE FUNCTION public.my_group_picks()
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_me TEXT := app_uid(); r RECORD;
BEGIN
    IF v_me IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
    FOR r IN SELECT g.id FROM group_picks g
             JOIN group_pick_members m ON m.pick_id = g.id AND lower(m.user_id) = lower(v_me)
             WHERE g.decided_at IS NULL AND g.decide_at <= now() LOOP
        PERFORM _maybe_decide_group_pick(r.id);
    END LOOP;
    RETURN COALESCE((
        SELECT json_agg(row_to_json(t) ORDER BY t.sort_at DESC)
        FROM (
            SELECT g.id,
                   g.title,
                   g.decided_place_id,
                   g.outcome,
                   g.decided_at,
                   g.decide_at,
                   (SELECT COUNT(*) FROM group_pick_members x WHERE x.pick_id = g.id) AS member_count,
                   cardinality(g.place_ids) AS place_count,
                   (SELECT COUNT(DISTINCT v.place_id) FROM group_pick_votes v
                    WHERE v.pick_id = g.id AND lower(v.user_id) = lower(v_me) AND v.place_id = ANY (g.place_ids)) AS voted_count,
                   (SELECT p.name FROM places p WHERE p.id = g.decided_place_id) AS place_name,
                   COALESCE(g.decided_at, g.created_at) AS sort_at
            FROM group_picks g
            JOIN group_pick_members m ON m.pick_id = g.id AND lower(m.user_id) = lower(v_me)
            WHERE g.decided_at IS NULL OR g.decided_at > now() - interval '24 hours'
            ORDER BY COALESCE(g.decided_at, g.created_at) DESC
            LIMIT 10
        ) t), '[]'::json);
END $$;

-- ---------------------------------------------------------------- server-side timeout (pg_cron)
CREATE OR REPLACE FUNCTION public.resolve_due_group_picks()
RETURNS INT LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE r RECORD; n INT := 0;
BEGIN
    FOR r IN SELECT id FROM group_picks WHERE decided_at IS NULL AND decide_at <= now() LOOP
        PERFORM _maybe_decide_group_pick(r.id);
        n := n + 1;
    END LOOP;
    RETURN n;
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        PERFORM cron.schedule('resolve-group-picks', '* * * * *', 'SELECT public.resolve_due_group_picks()');
    END IF;
END $$;

-- ---------------------------------------------------------------- grants
REVOKE ALL ON FUNCTION public._push_group_pick(TEXT, JSONB)               FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._group_pick_standings(UUID)                 FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._group_pick_pending_members(UUID)           FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._nudge_last_group_pick_voter(UUID, TEXT)    FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._maybe_decide_group_pick(UUID)              FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._group_pick_json(UUID)                      FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.resolve_due_group_picks()                   FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.vote_group_pick(UUID, TEXT, BOOLEAN)        FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.invite_group_pick_members(UUID, TEXT[])     FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.add_group_pick_places(UUID, TEXT[])         FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.my_group_picks()                            FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.vote_group_pick(UUID, TEXT, BOOLEAN)     TO authenticated;
GRANT EXECUTE ON FUNCTION public.invite_group_pick_members(UUID, TEXT[])  TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_group_pick_places(UUID, TEXT[])      TO authenticated;
GRANT EXECUTE ON FUNCTION public.my_group_picks()                         TO authenticated;
