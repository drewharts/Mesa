-- ============================================================================
-- Function: get_place_recommendations
-- ============================================================================
-- This file contains the current state of the function in the database.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_place_recommendations(p_user_id uuid, p_limit integer DEFAULT 20)
 RETURNS TABLE(place_id uuid, place_name text, address text, city text, latitude double precision, longitude double precision, saved_by_count bigint, saved_by_names text[])
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
        COUNT(DISTINCT f.user_id) AS saved_by_count,
        ARRAY_AGG(DISTINCT u.full_name) AS saved_by_names
    FROM places p
    JOIN favorites f ON p.id = f.place_id
    JOIN users u ON f.user_id = u.id
    WHERE f.user_id IN (
        SELECT following_id 
        FROM following 
        WHERE follower_id = p_user_id
    )
    -- Exclude places already saved by current user
    AND p.id NOT IN (
        SELECT place_id 
        FROM favorites 
        WHERE user_id = p_user_id
    )
    GROUP BY p.id, p.name, p.address, p.city, p.location
    ORDER BY saved_by_count DESC
    LIMIT p_limit;
END;
$function$
