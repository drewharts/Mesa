-- ============================================================================
-- Function: get_follower_profiles
-- ============================================================================
-- This file contains the current state of the function in the database.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_follower_profiles(user_id text)
 RETURNS TABLE(id text, first_name text, last_name text, full_name text, full_name_lower text, email text, phone_number text, profile_photo_url text, fcm_token text, created_at timestamp without time zone, supabase_uid text)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT u.*
    FROM users u
    INNER JOIN following f ON u.id = f.follower_id
    WHERE f.following_id = user_id;
END;
$function$
