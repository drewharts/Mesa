-- ============================================================================
-- Function: get_user_external_places_count
-- ============================================================================
-- Returns count of distinct external places (TikTok imports) for a user
-- Supports optional bounding box filtering for viewport-based queries
-- When bounding box params are NULL (default), returns total count
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_user_external_places_count(
    p_user_id text,
    p_min_lon double precision DEFAULT NULL,
    p_min_lat double precision DEFAULT NULL,
    p_max_lon double precision DEFAULT NULL,
    p_max_lat double precision DEFAULT NULL
)
RETURNS integer
LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN (
        SELECT COUNT(DISTINCT ep.place_id)::integer
        FROM external_places ep
        JOIN places p ON ep.place_id = p.id
        WHERE ep.user_id = p_user_id
          AND (p_min_lon IS NULL OR ST_Intersects(
              p.location,
              get_bounding_box(p_min_lon, p_min_lat, p_max_lon, p_max_lat)
          ))
    );
END;
$function$;
