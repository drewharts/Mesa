-- ============================================================================
-- Function: get_trending_places
-- ============================================================================
-- This file contains the current state of the function in the database.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_trending_places(p_user_lat double precision DEFAULT NULL::double precision, p_user_lng double precision DEFAULT NULL::double precision, p_radius_meters double precision DEFAULT 50000, p_limit integer DEFAULT 20)
 RETURNS TABLE(place_id uuid, place_name text, address text, city text, latitude double precision, longitude double precision, recent_favorites bigint, recent_reviews bigint, trending_score double precision)
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
        COUNT(DISTINCT f.id) FILTER (WHERE f."timestamp" > NOW() - INTERVAL '7 days') AS recent_favorites,
        COUNT(DISTINCT r.id) FILTER (WHERE r."timestamp" > NOW() - INTERVAL '7 days') AS recent_reviews,
        (COUNT(DISTINCT f.id) FILTER (WHERE f."timestamp" > NOW() - INTERVAL '7 days') * 2 + 
         COUNT(DISTINCT r.id) FILTER (WHERE r."timestamp" > NOW() - INTERVAL '7 days')) AS trending_score
    FROM places p
    LEFT JOIN favorites f ON p.id = f.place_id
    LEFT JOIN reviews r ON p.id = r.place_id
    WHERE 
        -- Optional location filter
        (p_user_lat IS NULL OR p_user_lng IS NULL) OR
        ST_DWithin(
            p.location::geography,
            ST_SetSRID(ST_MakePoint(p_user_lng, p_user_lat), 4326)::geography,
            p_radius_meters
        )
    GROUP BY p.id, p.name, p.address, p.city, p.location
    HAVING (COUNT(DISTINCT f.id) FILTER (WHERE f."timestamp" > NOW() - INTERVAL '7 days') + 
            COUNT(DISTINCT r.id) FILTER (WHERE r."timestamp" > NOW() - INTERVAL '7 days')) > 0
    ORDER BY trending_score DESC
    LIMIT p_limit;
END;
$function$
