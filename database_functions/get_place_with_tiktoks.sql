-- ============================================================================
-- Function: get_place_with_tiktoks
-- ============================================================================
-- Returns place details with TikTok videos
-- NOTE: TikTok metadata is now fetched on-demand in Swift via oEmbed endpoint
-- This function returns an empty array for tiktok_videos since we no longer
-- store TikTok metadata in the database (only the URL)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_place_with_tiktoks(p_place_id text)
 RETURNS TABLE(id text, name text, address text, city text, latitude double precision, longitude double precision, description text, phone text, website text, rating double precision, price_level text, categories text[], open_hours jsonb, photo_urls text[], mapbox_id text, is_custom boolean, menu_url text, instagram text, twitter text, tiktok_videos jsonb)
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
$function$
