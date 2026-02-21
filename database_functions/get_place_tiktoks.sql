-- ============================================================================
-- Function: get_place_tiktoks
-- ============================================================================
-- Returns external video URLs for a place from the external_places table.
-- Metadata (thumbnails, author info) is fetched on-demand in Swift via oEmbed.
-- Returns all sources (tiktok, instagram, etc).
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_place_tiktoks(p_place_id uuid)
RETURNS TABLE(tiktok_videos jsonb)
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    place_id_text text;
BEGIN
    -- Convert UUID to text for comparison with external_places.place_id (which is text)
    place_id_text := p_place_id::text;

    RETURN QUERY
    SELECT jsonb_agg(
        jsonb_build_object(
            'url', ep.url,
            'source', ep.source,
            'added_at', ep.added_at,
            'external_place_id', ep.id,
            'saved_by_user_id', ep.user_id,
            'saved_by_first_name', u.first_name,
            'saved_by_last_name', u.last_name,
            'saved_by_profile_photo_url', u.profile_photo_url
        )
    ) as tiktok_videos
    FROM external_places ep
    JOIN users u ON ep.user_id = u.id
    WHERE UPPER(ep.place_id) = UPPER(place_id_text)
      AND ep.url IS NOT NULL
      AND ep.url != '';
END;
$function$;
