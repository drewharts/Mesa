-- ============================================================================
-- Function: get_user_external_places
-- ============================================================================
-- Returns paginated list of external places (TikTok imports) for a user
-- Joins with places table to get name and coordinates
-- Supports optional bounding box filtering for viewport-based queries
-- When bounding box params are NULL (default), returns all places
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_user_external_places(
    p_user_id text,
    p_limit integer,
    p_offset integer,
    p_min_lon double precision DEFAULT NULL,
    p_min_lat double precision DEFAULT NULL,
    p_max_lon double precision DEFAULT NULL,
    p_max_lat double precision DEFAULT NULL
)
RETURNS TABLE(
    place_id text,
    name text,
    latitude double precision,
    longitude double precision,
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
        ST_Y(p.location)::double precision AS latitude,
        ST_X(p.location)::double precision AS longitude,
        get_latest_review_photo(ep.place_id) AS latest_review_photo,
        ep.id AS external_place_id,
        ep.url AS tiktok_url
    FROM external_places ep
    JOIN places p ON ep.place_id = p.id
    WHERE ep.user_id = p_user_id
      AND (p_min_lon IS NULL OR ST_Intersects(
          p.location,
          get_bounding_box(p_min_lon, p_min_lat, p_max_lon, p_max_lat)
      ))
    ORDER BY ep.added_at DESC NULLS LAST, ep.id DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$function$;
