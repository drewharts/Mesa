-- ============================================================================
-- FIX TIKTOK FUNCTIONS - Remove tiktok_videos column references
-- ============================================================================
-- This fixes functions that reference the removed tiktok_videos column
-- TikTok metadata is now fetched on-demand via oEmbed endpoint
--
-- Date: 2025-01-29
-- ============================================================================

-- ============================================================================
-- 1. Fix get_place_reviews_with_tiktoks
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
$function$;

-- ============================================================================
-- 2. Fix get_place_tiktoks
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_place_tiktoks(p_place_id text)
RETURNS TABLE(tiktok_videos jsonb)
LANGUAGE sql
STABLE
AS $function$
-- Return empty array since TikTok metadata is fetched on-demand
-- TikTok URLs are stored in external_places.url, but metadata comes from oEmbed API
SELECT '[]'::jsonb as tiktok_videos;
$function$;

-- ============================================================================
-- 3. Fix get_place_with_tiktoks
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_place_with_tiktoks(p_place_id text)
RETURNS TABLE(
    id text, 
    name text, 
    address text, 
    city text, 
    latitude double precision, 
    longitude double precision, 
    description text, 
    phone text, 
    website text, 
    rating double precision, 
    price_level text, 
    categories text[], 
    open_hours jsonb, 
    photo_urls text[], 
    mapbox_id text, 
    is_custom boolean, 
    menu_url text, 
    instagram text, 
    twitter text, 
    tiktok_videos jsonb
)
LANGUAGE sql
STABLE
AS $function$
SELECT 
    p.id,
    p.name,
    p.address,
    p.city,
    ST_Y(p.location) as latitude,
    ST_X(p.location) as longitude,
    p.description,
    p.phone,
    p.website,
    p.rating,
    p.price_level,
    p.categories,
    p.open_hours,
    p.photo_urls,
    p.mapbox_id,
    p.is_custom,
    p.menu_url,
    p.instagram,
    p.twitter,
    -- TikTok videos - now returns empty array since metadata is fetched on-demand
    -- TikTok URLs are stored in external_places.url, but metadata is fetched via oEmbed
    '[]'::jsonb as tiktok_videos
FROM places p
WHERE p.id = p_place_id;
$function$;

-- ============================================================================
-- 4. Fix get_places_for_tiktok_video (DEPRECATED)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_places_for_tiktok_video(p_video_id text, p_user_id text)
RETURNS TABLE(
    place_id text, 
    place_name text, 
    place_address text, 
    latitude double precision, 
    longitude double precision
)
LANGUAGE plpgsql
AS $function$
BEGIN
    -- Return empty results since we no longer store video_id in the database
    -- TikTok metadata is fetched on-demand, so we can't match by video_id
    RETURN QUERY
    SELECT 
        NULL::text AS place_id,
        NULL::text AS place_name,
        NULL::text AS place_address,
        NULL::double precision AS latitude,
        NULL::double precision AS longitude
    WHERE FALSE;
END;
$function$;

