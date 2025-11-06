-- ============================================================================
-- Function: notify_on_comment
-- ============================================================================
-- This file contains the current state of the function in the database.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.notify_on_comment()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    INSERT INTO user_notifications (
        id, user_id, type, actor_id, place_id, review_id, comment_id, "timestamp", is_read
    )
    SELECT 
        gen_random_uuid(),
        r.user_id,
        'comment',
        NEW.user_id,
        NEW.place_id,
        NEW.review_id,
        NEW.id,
        NEW."timestamp",
        false
    FROM reviews r
    WHERE r.id = NEW.review_id
    AND r.user_id != NEW.user_id;
    
    RETURN NEW;
END;
$function$
