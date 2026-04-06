-- ============================================================================
-- Function: get_user_feed
-- ============================================================================
-- This file contains the current state of the function in the database.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_user_feed(p_user_id text, p_limit integer DEFAULT 50, p_offset integer DEFAULT 0)
 RETURNS TABLE(review_id text, user_id text, user_first_name text, user_last_name text, profile_photo_url text, place_id text, place_name text, food_rating double precision, service_rating double precision, ambience_rating double precision, review_text text, images text[], review_timestamp timestamp without time zone, likes integer, would_return boolean, latitude double precision, longitude double precision, comment_count integer)
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
        r.likes,
        r.would_return,
        ST_Y(p.location::geometry) AS latitude,
        ST_X(p.location::geometry) AS longitude,
        (SELECT COUNT(*) FROM comments c WHERE c.review_id = r.id)::integer AS comment_count
    FROM reviews r
    JOIN places p ON r.place_id = p.id
    WHERE (r.user_id IN (
        SELECT f.following_id
        FROM following f
        JOIN users u ON f.following_id = u.id
        WHERE f.follower_id = p_user_id
        AND (u.account_type IS NULL OR u.account_type != 'curated')
    )
    OR r.user_id = p_user_id)
    AND r.images IS NOT NULL AND array_length(r.images, 1) > 0
    ORDER BY r."timestamp" DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$function$
