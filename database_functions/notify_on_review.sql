-- ============================================================================
-- Function: notify_on_review
-- ============================================================================
-- This file contains the current state of the function in the database.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.notify_on_review()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    INSERT INTO user_notifications (
        id, user_id, type, actor_id, actor_first_name, actor_last_name, 
        actor_profile_photo_url, place_id, place_name, review_id, "timestamp", is_read
    )
    SELECT 
        gen_random_uuid(),
        f.user_id,
        'review',
        NEW.user_id,
        NEW.user_first_name,
        NEW.user_last_name,
        NEW.profile_photo_url,
        NEW.place_id,
        NEW.place_name,
        NEW.id,
        NEW."timestamp",
        false
    FROM favorites f
    WHERE f.place_id = NEW.place_id
    AND f.user_id != NEW.user_id;
    
    RETURN NEW;
END;
$function$
