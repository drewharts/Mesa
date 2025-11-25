-- ============================================================================
-- Function: get_nearby_places
-- ============================================================================
-- This file contains the current state of the function in the database.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_nearby_places(p_lat double precision, p_lng double precision, p_radius_meters double precision DEFAULT 5000)
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
        ST_Distance(
            p.location::geography,
            ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography
        ) AS distance_meters,
        p.rating,
        p.categories
    FROM places p
    WHERE ST_DWithin(
        p.location::geography,
        ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
        p_radius_meters
    )
    ORDER BY distance_meters;
END;
$function$
