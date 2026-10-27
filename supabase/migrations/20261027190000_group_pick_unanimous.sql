-- ============================================================================
-- Migration: Group picks decide immediately on a unanimous yes
-- ============================================================================
-- Approved by Drew 2026-10-27 2:18 PM ET after the 20261027 rules made a 2-person pick
-- (both yes on the same place, other places unvoted) wait for the 90-minute timeout.
--
-- Changes:
--   * _maybe_decide_group_pick: 'unanimous' no longer waits for better-ranked unvoted places.
--     When every current member (>= 2) said yes to one place, the pick is decided at once.
--     If several places are unanimous, the usual order picks one (fewest no, then Tonight rank).
--     The 'clear_winner' (majority that can't be caught) and timeout rules are unchanged.
--   * resolve_due_group_picks (pg_cron, every minute) now checks every undecided pick, not only
--     those past decide_at, so existing picks that already qualify resolve within a minute.
-- ============================================================================

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

CREATE OR REPLACE FUNCTION public.resolve_due_group_picks()
RETURNS INT LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE r RECORD; n INT := 0;
BEGIN
    FOR r IN SELECT id FROM group_picks WHERE decided_at IS NULL LOOP
        PERFORM _maybe_decide_group_pick(r.id);
        n := n + 1;
    END LOOP;
    RETURN n;
END $$;

REVOKE ALL ON FUNCTION public._maybe_decide_group_pick(UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.resolve_due_group_picks()      FROM PUBLIC, anon, authenticated;
