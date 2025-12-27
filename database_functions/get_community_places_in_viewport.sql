-- ============================================================================
-- Function: get_community_places_in_viewport
-- ============================================================================
-- Returns places saved by users OUTSIDE the current user's network (self + following)
-- These are displayed as small emoji markers on the map to show community activity
-- even when the user doesn't follow anyone with saved places nearby
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_community_places_in_viewport(
    p_user_id text, 
    p_min_lon double precision, 
    p_min_lat double precision, 
    p_max_lon double precision, 
    p_max_lat double precision,
    p_limit integer DEFAULT 500
)
RETURNS TABLE(id text, name text, latitude double precision, longitude double precision, save_count bigint, place_type text)
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_user_friends text[];
    v_bbox geometry;
BEGIN
    -- Get user's network (self + following)
    v_user_friends := ARRAY(SELECT * FROM get_user_and_friends(p_user_id));
    v_bbox := get_bounding_box(p_min_lon, p_min_lat, p_max_lon, p_max_lat);

    RETURN QUERY
    SELECT 
        p.id::text,
        p.name,
        ST_Y(p.location::geometry) AS latitude,
        ST_X(p.location::geometry) AS longitude,
        COUNT(DISTINCT f.user_id) AS save_count,
        COALESCE(p.categories[1], 'Place') AS place_type
    FROM places p
    JOIN favorites f ON p.id::text = f.place_id::text
    WHERE 
        -- In viewport
        ST_Intersects(p.location, v_bbox)
        -- NOT saved by user's network (shows only "other" users' saves)
        AND f.user_id::text != ALL(v_user_friends)
        -- Exclude places already in user's network to avoid duplicates
        AND NOT EXISTS (
            SELECT 1 FROM favorites f2 
            WHERE f2.place_id::text = p.id::text 
            AND f2.user_id::text = ANY(v_user_friends)
        )
    GROUP BY p.id, p.name, p.location, p.categories
    ORDER BY save_count DESC
    LIMIT p_limit;
END;
$function$;

