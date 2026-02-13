-- ============================================================================
-- Migration: Add video support to reviews
-- ============================================================================
-- Adds video_urls and video_thumbnail_urls columns to the reviews table
-- to support mixed photo/video posts.
-- ============================================================================

ALTER TABLE reviews ADD COLUMN IF NOT EXISTS video_urls TEXT[] DEFAULT '{}';
ALTER TABLE reviews ADD COLUMN IF NOT EXISTS video_thumbnail_urls TEXT[] DEFAULT '{}';
