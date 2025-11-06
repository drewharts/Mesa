-- ============================================================================
-- Function: get_place_list_with_items
-- ============================================================================
-- This file contains the current state of the function in the database.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_place_list_with_items(p_list_id uuid)
 RETURNS TABLE(list_id uuid, list_name text, list_description text, is_public boolean, place_id uuid, place_name text, place_address text, city text, latitude double precision, longitude double precision, rating double precision, sort_order integer)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        pl.id AS list_id,
        pl.name AS list_name,
        pl.description AS list_description,
        pl.is_public,
        p.id AS place_id,
        p.name AS place_name,
        p.address AS place_address,
        p.city,
        ST_Y(p.location::geometry) AS latitude,
        ST_X(p.location::geometry) AS longitude,
        p.rating,
        pli.sort_order
    FROM place_lists pl
    LEFT JOIN place_list_items pli ON pl.id = pli.list_id
    LEFT JOIN places p ON pli.place_id = p.id
    WHERE pl.id = p_list_id
    ORDER BY pli.sort_order NULLS LAST;
END;
$function$
