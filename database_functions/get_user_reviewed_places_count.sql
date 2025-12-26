-- ============================================================================
-- Function: get_user_reviewed_places_count
-- ============================================================================
-- Returns the total count of distinct places reviewed by a user
-- Used for displaying accurate count in Reviews popup header
-- Note: user_id column is TEXT (not UUID) - do not cast
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_user_reviewed_places_count(p_user_id text)
RETURNS integer
LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN (
        SELECT COUNT(DISTINCT place_id)::integer
        FROM reviews
        WHERE user_id = p_user_id
    );
END;
$function$;

