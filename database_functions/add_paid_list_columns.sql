-- ============================================================================
-- Migration: Add paid list columns to place_lists
-- ============================================================================
-- Adds pricing support to place lists for monetization.
-- price_tier: null means free, otherwise maps to a StoreKit product tier
-- preview_place_count: number of places visible in the teaser for paid lists
--
-- SAFETY: All existing RPCs using explicit RETURNS TABLE columns are safe.
-- New columns are nullable/defaulted so existing rows are unaffected.
-- ============================================================================

ALTER TABLE place_lists
  ADD COLUMN IF NOT EXISTS price_tier TEXT DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS preview_place_count INT DEFAULT 3;
