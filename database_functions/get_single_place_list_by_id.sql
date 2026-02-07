-- ============================================================================
-- Function: get_single_place_list_by_id
-- ============================================================================
-- Fetches a single place list by ID with the same structure as 
-- LightweightPlaceList expects.
-- Used for deep link navigation when the list isn't in the first paginated results.
-- Note: city column doesn't exist in place_lists table, so we return NULL.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_single_place_list_by_id(p_list_id text)
RETURNS TABLE(
    list_id text,
    name text,
    is_public boolean,
    image text,
    created_at text,
    updated_at text,
    distance_meters double precision,
    place_count bigint,
    city text,
    average_location text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
    RETURN QUERY
    SELECT
        pl.id::text AS list_id,
        pl.name,
        pl.is_public,
        pl.image,
        pl.created_at::text,
        pl.updated_at::text,
        NULL::double precision AS distance_meters,
        COUNT(pli.place_id) AS place_count,
        NULL::text AS city,
        ST_AsText(pl.average_location) AS average_location
    FROM place_lists pl
    LEFT JOIN place_list_items pli ON pl.id::text = pli.list_id::text
    WHERE pl.id::text = p_list_id
    GROUP BY pl.id, pl.name, pl.is_public, pl.image, pl.created_at, pl.updated_at, pl.average_location;
END;
$function$;
