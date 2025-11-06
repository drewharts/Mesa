-- ============================================================================
-- Function: notify_on_follow
-- ============================================================================
-- This file contains the current state of the function in the database.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.notify_on_follow()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
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
$function$
