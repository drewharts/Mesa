-- ============================================================================
-- Function: get_user_place_lists_by_proximity
-- ============================================================================
-- This file contains the current state of the function in the database.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_user_place_lists_by_proximity(p_user_id text, p_user_lat double precision DEFAULT NULL::double precision, p_user_lng double precision DEFAULT NULL::double precision)
 RETURNS TABLE(id text, user_id text, name text, description text, sort_order integer, average_location text, is_public boolean, image text, created_at timestamp without time zone, updated_at timestamp without time zone, distance_meters double precision)
 LANGUAGE plpgsql
AS $function$BEGIN
    RETURN QUERY
    SELECT 
        pl.id,
        pl.user_id,
        pl.name,
        pl.description,
        pl.sort_order,
        ST_AsText(pl.average_location) AS average_location,
        pl.is_public,
        pl.image,
        pl.created_at,
        pl.updated_at,
        CASE 
            WHEN p_user_lat IS NOT NULL AND p_user_lng IS NOT NULL AND pl.average_location IS NOT NULL THEN
                ST_Distance(
                    pl.average_location::geography,
                    ST_SetSRID(ST_MakePoint(p_user_lng, p_user_lat), 4326)::geography
                )
            ELSE NULL
        END AS distance_meters
    FROM place_lists pl
    WHERE pl.user_id = p_user_id
    ORDER BY 
        CASE 
            WHEN p_user_lat IS NOT NULL AND p_user_lng IS NOT NULL AND pl.average_location IS NOT NULL THEN
                ST_Distance(
                    pl.average_location::geography,
                    ST_SetSRID(ST_MakePoint(p_user_lng, p_user_lat), 4326)::geography
                )
            ELSE pl.sort_order
        END ASC NULLS LAST,
        pl.name ASC;
END;$function$
