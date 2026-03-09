-- ============================================================================
-- One-time backfill: Populate city for all existing place_lists
-- ============================================================================
-- Run after deploying calculate_place_list_city and add_city_to_place_lists.
-- Safe to re-run; only updates rows where city is currently NULL.
-- ============================================================================

UPDATE place_lists
SET city = calculate_place_list_city(id::text)
WHERE city IS NULL;
