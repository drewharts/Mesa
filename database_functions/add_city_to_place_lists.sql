-- ============================================================================
-- Migration: Add city column to place_lists
-- ============================================================================
-- Adds a city TEXT column to place_lists for auto-grouping lists by city.
-- The city is derived from the most common city among a list's places,
-- maintained automatically by the existing place_list_items trigger.
-- ============================================================================

ALTER TABLE place_lists ADD COLUMN IF NOT EXISTS city TEXT;
CREATE INDEX IF NOT EXISTS idx_place_lists_city ON place_lists(city);
