-- ============================================================================
-- Function: get_map_places_in_viewport
-- ============================================================================
-- This file contains the current state of the function in the database.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_map_places_in_viewport(p_user_id uuid, p_north_lat double precision, p_south_lat double precision, p_east_lng double precision, p_west_lng double precision)
 RETURNS TABLE(place_id uuid, place_name text, latitude double precision, longitude double precision, saved_by_user_id uuid, saved_at timestamp without time zone)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    -- User's own favorites in viewport
    SELECT 
        p.id AS place_id,
        p.name AS place_name,
        ST_Y(p.location::geometry) AS latitude,
        ST_X(p.location::geometry) AS longitude,
        f.user_id AS saved_by_user_id,
        f."timestamp" AS saved_at
    FROM places p
    JOIN favorites f ON p.id = f.place_id
    WHERE f.user_id = p_user_id
      AND ST_Y(p.location::geometry) BETWEEN p_south_lat AND p_north_lat
      AND ST_X(p.location::geometry) BETWEEN p_west_lng AND p_east_lng
    
    UNION ALL
    
    -- Following users' favorites in viewport
    SELECT 
        p.id AS place_id,
        p.name AS place_name,
        ST_Y(p.location::geometry) AS latitude,
        ST_X(p.location::geometry) AS longitude,
        f.user_id AS saved_by_user_id,
        f."timestamp" AS saved_at
    FROM places p
    JOIN favorites f ON p.id = f.place_id
    JOIN following fo ON f.user_id = fo.following_id
    WHERE fo.follower_id = p_user_id
      AND ST_Y(p.location::geometry) BETWEEN p_south_lat AND p_north_lat
      AND ST_X(p.location::geometry) BETWEEN p_west_lng AND p_east_lng;
END;
$function$
