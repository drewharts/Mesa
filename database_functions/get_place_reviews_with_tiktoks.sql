-- ============================================================================
-- Function: get_place_reviews_with_tiktoks
-- ============================================================================
-- Returns reviews for a place with TikTok videos array
-- NOTE: TikTok metadata is now fetched on-demand in Swift via oEmbed endpoint
-- This function returns an empty array for tiktok_videos since we no longer
-- store TikTok metadata in the database (only the URL)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_place_reviews_with_tiktoks(
    p_place_id text, 
    p_limit integer DEFAULT 4, 
    p_offset integer DEFAULT 0
)
RETURNS TABLE(
    review_id text, 
    review_user_id text, 
    review_text text, 
    review_images text[], 
    review_timestamp timestamp without time zone, 
    review_type text, 
    review_likes integer, 
    user_first_name text, 
    user_last_name text, 
    user_profile_photo_url text, 
    tiktok_videos jsonb[]
)
LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        -- Reviews columns
        r.id AS review_id,
        r.user_id AS review_user_id,
        r.review_text,
        r.images AS review_images,
        r.timestamp AS review_timestamp,
        r.type AS review_type,
        r.likes AS review_likes,
        
        -- User information (CURRENT from users table via JOIN)
        u.first_name AS user_first_name,
        u.last_name AS user_last_name,
        u.profile_photo_url AS user_profile_photo_url,
        
        -- TikTok videos - now returns empty array since metadata is fetched on-demand
        -- TikTok URLs are stored in external_places.url, but metadata is fetched via oEmbed
        '{}'::jsonb[] AS tiktok_videos
    FROM reviews r
    INNER JOIN users u ON r.user_id = u.id
    WHERE r.place_id = p_place_id
    ORDER BY r.timestamp DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$function$
