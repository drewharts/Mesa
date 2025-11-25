-- ============================================================================
-- Function: get_user_feed
-- ============================================================================
-- This file contains the current state of the function in the database.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_user_feed(p_user_id uuid, p_limit integer DEFAULT 50, p_offset integer DEFAULT 0)
 RETURNS TABLE(review_id uuid, user_id uuid, user_first_name text, user_last_name text, profile_photo_url text, place_id uuid, place_name text, food_rating double precision, service_rating double precision, ambience_rating double precision, review_text text, images text[], review_timestamp timestamp without time zone, likes integer)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        r.id AS review_id,
        r.user_id,
        r.user_first_name,
        r.user_last_name,
        r.profile_photo_url,
        r.place_id,
        r.place_name,
        r.food_rating,
        r.service_rating,
        r.ambience_rating,
        r.review_text,
        r.images,
        r."timestamp" AS review_timestamp,
        r.likes
    FROM reviews r
    WHERE r.user_id IN (
        SELECT following_id 
        FROM following 
        WHERE follower_id = p_user_id
    )
    OR r.user_id = p_user_id
    ORDER BY r."timestamp" DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$function$
