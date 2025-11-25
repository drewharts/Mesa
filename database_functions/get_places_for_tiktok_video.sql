-- ============================================================================
-- Function: get_places_for_tiktok_video
-- ============================================================================
-- DEPRECATED: This function is no longer functional since we no longer store
-- TikTok video metadata (video_id) in the database. TikTok metadata is now
-- fetched on-demand via oEmbed endpoint.
-- 
-- This function returns empty results since we can't match by video_id anymore.
-- Consider using external_places.url to find places by TikTok URL instead.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_places_for_tiktok_video(p_video_id text, p_user_id text)
RETURNS TABLE(place_id text, place_name text, place_address text, latitude double precision, longitude double precision)
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
$function$
