-- ============================================================================
-- Migration: Fix following table created_at column
-- ============================================================================
-- Issue: created_at column is nullable with no default, causing NULL values
--        and potential trigger errors when following users
-- ============================================================================

-- Step 1: Update existing NULL created_at values to current timestamp
UPDATE public.following
SET created_at = NOW()
WHERE created_at IS NULL;

-- Step 2: Add DEFAULT NOW() to created_at column
ALTER TABLE public.following
ALTER COLUMN created_at SET DEFAULT NOW();

-- Step 3: Ensure the trigger function is correct (it already uses COALESCE, but let's make sure)
CREATE OR REPLACE FUNCTION public.notify_on_follow()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO user_notifications (
        id, user_id, type, actor_id, "timestamp", is_read
    )
    VALUES (
        gen_random_uuid(),
        NEW.following_id,
        'follow',
        NEW.follower_id,
        COALESCE(NEW.created_at, NOW()),
        false
    );
    
    RETURN NEW;
END;
$$;

-- Step 4: Ensure trigger exists (idempotent)
DROP TRIGGER IF EXISTS trigger_notify_on_follow ON public.following;
CREATE TRIGGER trigger_notify_on_follow
    AFTER INSERT ON public.following
    FOR EACH ROW
    EXECUTE FUNCTION notify_on_follow();

-- ============================================================================
-- Migration Complete
-- ============================================================================
-- This migration:
-- 1. Updates all existing NULL created_at values
-- 2. Adds DEFAULT NOW() so new inserts automatically get a timestamp
-- 3. Ensures the trigger function is correct
-- 4. Recreates the trigger to ensure it's properly attached
-- ============================================================================

