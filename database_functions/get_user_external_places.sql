-- ============================================================================
-- Function: get_user_external_places
-- ============================================================================
-- Returns paginated list of external places (TikTok imports) for a user
-- Joins with places table to get name and coordinates
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_user_external_places(
    p_user_id text,
    p_limit integer,
    p_offset integer
)
RETURNS TABLE(
    place_id text,
    name text,
    coordinate geometry,
    latest_review_photo text,
    external_place_id text,
    tiktok_url text
)
LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        ep.place_id,
        p.name,
        p.location AS coordinate,
        get_latest_review_photo(ep.place_id) AS latest_review_photo,
        ep.id AS external_place_id,
        ep.url AS tiktok_url
    FROM external_places ep
    JOIN places p ON ep.place_id = p.id
    WHERE ep.user_id = p_user_id
    ORDER BY ep.added_at DESC NULLS LAST, ep.id DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$function$;
