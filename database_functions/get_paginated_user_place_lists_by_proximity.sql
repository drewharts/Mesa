-- ============================================================================
-- Function: get_paginated_user_place_lists_by_proximity
-- ============================================================================
-- This file contains the current state of the function in the database.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_paginated_user_place_lists_by_proximity(p_user_id text, p_user_location geometry, p_page integer, p_page_size integer)
 RETURNS TABLE(list_id text, name text, average_location geometry, is_public boolean, image text, created_at timestamp without time zone, updated_at timestamp without time zone, distance_meters double precision, place_count bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        pl.id AS list_id,
        pl.name,
        pl.average_location,
        pl.is_public,
        pl.image,
        pl.created_at,
        pl.updated_at,
        ST_Distance(pl.average_location, p_user_location) AS distance_meters,
        COUNT(pli.place_id) AS place_count
    FROM place_lists pl
    LEFT JOIN place_list_items pli ON pl.id = pli.list_id
    WHERE pl.user_id = p_user_id
        AND pl.average_location IS NOT NULL
    GROUP BY pl.id, pl.name, pl.average_location, pl.is_public, pl.image, pl.created_at, pl.updated_at
    ORDER BY ST_Distance(pl.average_location, p_user_location) ASC
    OFFSET (p_page - 1) * p_page_size
    LIMIT p_page_size;
END;
$function$
