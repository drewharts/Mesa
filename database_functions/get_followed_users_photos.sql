-- ============================================================================
-- Function: get_followed_users_photos
-- ============================================================================
-- This file contains the current state of the function in the database.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_followed_users_photos(p_user_id text)
 RETURNS SETOF followed_user_photo
 LANGUAGE sql
 SECURITY DEFINER
AS $function$
SELECT 
    u.id AS user_id,
    u.profile_photo_url
FROM users u
INNER JOIN get_followed_users(p_user_id) AS f (following_id) ON u.id = f.following_id;
$function$
