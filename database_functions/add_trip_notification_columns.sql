-- ============================================================================
-- Schema Migration: Add Trip Fields to user_notifications
-- ============================================================================
-- This migration adds support for trip notification types by:
-- 1. Adding trip_id and trip_name columns
-- 2. Updating the type CHECK constraint to include trip notification types
-- ============================================================================

-- Add trip_id column for referencing the trip
ALTER TABLE user_notifications ADD COLUMN IF NOT EXISTS trip_id TEXT;

-- Add trip_name column for displaying trip name in notifications
ALTER TABLE user_notifications ADD COLUMN IF NOT EXISTS trip_name TEXT;

-- Drop the existing type constraint
ALTER TABLE user_notifications DROP CONSTRAINT IF EXISTS user_notifications_type_check;

-- Add updated type constraint including the new trip notification types
ALTER TABLE user_notifications ADD CONSTRAINT user_notifications_type_check
    CHECK (type IN (
        'review', 'comment', 'like', 'follow', 'friend_review',
        'place_added_to_list',
        'trip_collaborator_added', 'place_added_to_trip', 'trip_updated'
    ));

-- Verify changes
DO $$
BEGIN
    RAISE NOTICE '✅ Schema migration completed successfully';
    RAISE NOTICE 'Added columns: trip_id, trip_name';
    RAISE NOTICE 'Updated type constraint to include: trip_collaborator_added, place_added_to_trip, trip_updated';
END $$;
