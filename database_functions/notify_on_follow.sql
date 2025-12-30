-- ============================================================================
-- Function: notify_on_follow
-- ============================================================================
-- This file contains the current state of the function in the database.
-- ============================================================================
-- Creates a notification when a user is followed, including the follower's
-- name and profile photo for display in push notifications.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.notify_on_follow()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO user_notifications (
        id, user_id, type, actor_id, actor_first_name, actor_last_name, 
        actor_profile_photo_url, "timestamp", is_read
    )
    SELECT 
        gen_random_uuid(),
        NEW.following_id,
        'follow',
        NEW.follower_id,
        u.first_name,
        u.last_name,
        u.profile_photo_url,
        NOW(),
        false
    FROM users u
    WHERE u.id = NEW.follower_id
       OR u.supabase_uid = NEW.follower_id
       OR u.firebase_uid = NEW.follower_id;
    
    RETURN NEW;
END;
$$;
