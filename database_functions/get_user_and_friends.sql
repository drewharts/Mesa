-- ============================================================================
-- Function: get_user_and_friends
-- ============================================================================
-- Returns the user ID plus all followed user IDs as a set
-- Used for queries that need to include places from user and their network
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_user_and_friends(p_user_id text)
RETURNS SETOF text
LANGUAGE sql
AS $function$
SELECT p_user_id
UNION
SELECT * FROM get_followed_users(p_user_id);
$function$;

