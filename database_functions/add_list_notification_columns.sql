-- ============================================================================
-- Schema Migration: Add List Fields to user_notifications
-- ============================================================================
-- This migration adds support for "place_added_to_list" notifications by:
-- 1. Adding list_id and list_name columns
-- 2. Updating the type CHECK constraint to include 'place_added_to_list'
-- ============================================================================

-- Add list_id column for referencing the list
ALTER TABLE user_notifications ADD COLUMN IF NOT EXISTS list_id TEXT REFERENCES place_lists(id);

-- Add list_name column for displaying list name in notifications
ALTER TABLE user_notifications ADD COLUMN IF NOT EXISTS list_name TEXT;

-- Drop the existing type constraint
ALTER TABLE user_notifications DROP CONSTRAINT IF EXISTS user_notifications_type_check;

-- Add updated type constraint including the new notification type
-- Note: includes 'friend_review' which exists in production data
ALTER TABLE user_notifications ADD CONSTRAINT user_notifications_type_check
    CHECK (type IN ('review', 'comment', 'like', 'follow', 'friend_review', 'place_added_to_list'));

-- Verify changes
DO $$
BEGIN
    RAISE NOTICE '✅ Schema migration completed successfully';
    RAISE NOTICE 'Added columns: list_id, list_name';
    RAISE NOTICE 'Updated type constraint to include: place_added_to_list';
END $$;
