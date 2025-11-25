-- ============================================================================
-- Function: notify_on_review_like
-- ============================================================================
-- This file contains the current state of the function in the database.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.notify_on_review_like()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    INSERT INTO user_notifications (
        id, user_id, type, actor_id, review_id, "timestamp", is_read
    )
    SELECT 
        gen_random_uuid(),
        r.user_id,
        'like',
        NEW.user_id,
        NEW.review_id,
        NEW."timestamp",
        false
    FROM reviews r
    WHERE r.id = NEW.review_id
    AND r.user_id != NEW.user_id;
    
    -- Also increment likes count on review
    UPDATE reviews
    SET likes = likes + 1
    WHERE id = NEW.review_id;
    
    RETURN NEW;
END;
$function$
