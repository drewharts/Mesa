-- ============================================================================
-- Function: get_user_created_places_count
-- ============================================================================
-- Returns the total count of places created by a user (from my_places table)
-- Used for displaying accurate totals in the My Places popup header
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_user_created_places_count(p_user_id text)
RETURNS integer
LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN (
        SELECT COUNT(*)::integer
        FROM my_places
        WHERE user_id = p_user_id
    );
END;
$function$;

