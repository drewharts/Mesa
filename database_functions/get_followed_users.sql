-- ============================================================================
-- Function: get_followed_users
-- ============================================================================
-- This file contains the current state of the function in the database.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_followed_users(p_user_id text)
 RETURNS SETOF text
 LANGUAGE sql
AS $function$
SELECT following_id FROM following WHERE follower_id = p_user_id;
$function$
