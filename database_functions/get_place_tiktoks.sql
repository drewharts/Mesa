-- ============================================================================
-- Function: get_place_tiktoks
-- ============================================================================
-- Returns TikTok videos for a place
-- NOTE: TikTok metadata is now fetched on-demand in Swift via oEmbed endpoint
-- This function returns an empty array since we no longer store TikTok metadata
-- in the database (only the URL in external_places.url)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_place_tiktoks(p_place_id text)
RETURNS TABLE(tiktok_videos jsonb)
LANGUAGE sql
STABLE
AS $function$
-- Return empty array since TikTok metadata is fetched on-demand
-- TikTok URLs are stored in external_places.url, but metadata comes from oEmbed API
SELECT '[]'::jsonb as tiktok_videos;
$function$
