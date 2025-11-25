-- ============================================================================
-- Function: decrement_review_likes
-- ============================================================================
-- This file contains the current state of the function in the database.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.decrement_review_likes()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    UPDATE reviews
    SET likes = GREATEST(likes - 1, 0)
    WHERE id = OLD.review_id;
    
    RETURN OLD;
END;
$function$
