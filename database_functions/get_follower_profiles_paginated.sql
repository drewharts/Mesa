-- ============================================================================
-- Function: get_follower_profiles_paginated
-- ============================================================================
-- This file contains the current state of the function in the database.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_follower_profiles_paginated(user_id text, page_size integer, page_number integer)
 RETURNS TABLE(id text, first_name text, last_name text, full_name text, full_name_lower text, email text, phone_number text, profile_photo_url text, fcm_token text, created_at timestamp without time zone, supabase_uid text)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT u.*
    FROM users u
    INNER JOIN following f ON u.id = f.follower_id
    WHERE f.following_id = user_id
    ORDER BY f.created_at DESC
    LIMIT page_size
    OFFSET (page_number - 1) * page_size;
END;
$function$
