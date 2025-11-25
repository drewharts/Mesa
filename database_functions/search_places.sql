-- ============================================================================
-- Function: search_places
-- ============================================================================
-- This file contains the current state of the function in the database.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.search_places(p_search_term text, p_user_lat double precision DEFAULT NULL::double precision, p_user_lng double precision DEFAULT NULL::double precision, p_radius_meters double precision DEFAULT 50000, p_limit integer DEFAULT 50)
 RETURNS TABLE(place_id uuid, place_name text, address text, city text, latitude double precision, longitude double precision, distance_meters double precision, rating double precision, categories text[])
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        p.id AS place_id,
        p.name AS place_name,
        p.address,
        p.city,
        ST_Y(p.location::geometry) AS latitude,
        ST_X(p.location::geometry) AS longitude,
        CASE 
            WHEN p_user_lat IS NOT NULL AND p_user_lng IS NOT NULL THEN
                ST_Distance(
                    p.location::geography,
                    ST_SetSRID(ST_MakePoint(p_user_lng, p_user_lat), 4326)::geography
                )
            ELSE NULL
        END AS distance_meters,
        p.rating,
        p.categories
    FROM places p
    WHERE 
        -- Text search
        (
            p.name ILIKE '%' || p_search_term || '%' OR
            p.city ILIKE '%' || p_search_term || '%' OR
            p.address ILIKE '%' || p_search_term || '%'
        )
        -- Optional geospatial filter
        AND (
            (p_user_lat IS NULL OR p_user_lng IS NULL) OR
            ST_DWithin(
                p.location::geography,
                ST_SetSRID(ST_MakePoint(p_user_lng, p_user_lat), 4326)::geography,
                p_radius_meters
            )
        )
    ORDER BY 
        CASE 
            WHEN p_user_lat IS NOT NULL AND p_user_lng IS NOT NULL THEN distance_meters
            ELSE NULL
        END ASC NULLS LAST,
        p.name ASC
    LIMIT p_limit;
END;
$function$
