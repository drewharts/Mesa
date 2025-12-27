-- ============================================================================
-- Function: get_community_places_in_viewport
-- ============================================================================
-- Returns places saved by users OUTSIDE the current user's network (self + following)
-- These are displayed as small emoji markers on the map to show community activity
-- even when the user doesn't follow anyone with saved places nearby
-- 
-- Counts saves from ALL sources: favorites, place_list_items, my_places, 
-- external_places (TikTok), and reviews
-- 
-- Uses enterprise-grade grid-based clustering (same as Google Maps/Mapbox)
-- for O(n) performance instead of O(n²) distance-based filtering
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_community_places_in_viewport(
    p_user_id text, 
    p_min_lon double precision, 
    p_min_lat double precision, 
    p_max_lon double precision, 
    p_max_lat double precision,
    p_grid_cells_across integer DEFAULT 30  -- More cells = more markers for community places
)
RETURNS TABLE(id text, name text, latitude double precision, longitude double precision, save_count bigint, place_type text)
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_user_friends text[];
    v_bbox geometry;
    v_grid_size_lon double precision;
    v_grid_size_lat double precision;
BEGIN
    v_user_friends := ARRAY(SELECT * FROM get_user_and_friends(p_user_id));
    v_bbox := get_bounding_box(p_min_lon, p_min_lat, p_max_lon, p_max_lat);
    
    -- Calculate grid cell size based on viewport (adaptive to zoom level)
    v_grid_size_lon := (p_max_lon - p_min_lon) / p_grid_cells_across;
    v_grid_size_lat := (p_max_lat - p_min_lat) / p_grid_cells_across;

    RETURN QUERY
    -- Combine all save sources into one unified view
    WITH all_saves AS (
        -- Favorites
        SELECT 
            f.place_id::text AS place_id,
            f.user_id::text AS user_id
        FROM favorites f
        
        UNION ALL
        
        -- Place list items (use added_by if available, fall back to list owner)
        SELECT 
            pli.place_id::text AS place_id,
            COALESCE(pli.added_by, pl.user_id)::text AS user_id
        FROM place_list_items pli
        JOIN place_lists pl ON pli.list_id = pl.id
        
        UNION ALL
        
        -- My places (user-created places)
        SELECT 
            mp.place_id::text AS place_id,
            mp.user_id::text AS user_id
        FROM my_places mp
        
        UNION ALL
        
        -- External places (TikTok, etc.)
        SELECT 
            ep.place_id::text AS place_id,
            ep.user_id::text AS user_id
        FROM external_places ep
        
        UNION ALL
        
        -- Reviews (reviewed places count as saves)
        SELECT 
            r.place_id::text AS place_id,
            r.user_id::text AS user_id
        FROM reviews r
    ),
    -- Filter to non-network saves and aggregate
    community_saves AS (
        SELECT 
            s.place_id,
            COUNT(DISTINCT s.user_id) AS save_count
        FROM all_saves s
        WHERE 
            -- Only count saves from users OUTSIDE the network
            s.user_id != ALL(v_user_friends)
            -- Exclude places that anyone in the network has saved
            AND NOT EXISTS (
                SELECT 1 FROM all_saves s2 
                WHERE s2.place_id = s.place_id 
                AND s2.user_id = ANY(v_user_friends)
            )
        GROUP BY s.place_id
    ),
    -- Join with places table to get location and details
    places_with_location AS (
        SELECT 
            p.id::text AS place_id,
            p.name AS place_name,
            p.location AS place_location,
            ST_Y(p.location::geometry) AS lat,
            ST_X(p.location::geometry) AS lon,
            cs.save_count AS saves,
            COALESCE(p.categories[1], 'Place') AS ptype,
            -- Snap to grid for clustering (O(n) operation)
            ST_SnapToGrid(p.location::geometry, v_grid_size_lon, v_grid_size_lat) AS grid_cell
        FROM community_saves cs
        JOIN places p ON cs.place_id = p.id::text
        WHERE ST_Intersects(p.location, v_bbox)
    ),
    -- Pick ONE representative per grid cell (the one with most saves)
    clustered AS (
        SELECT DISTINCT ON (grid_cell)
            place_id,
            place_name,
            lat,
            lon,
            saves,
            ptype
        FROM places_with_location
        ORDER BY grid_cell, saves DESC
    )
    SELECT 
        place_id AS id,
        place_name AS name,
        lat AS latitude,
        lon AS longitude,
        saves AS save_count,
        ptype AS place_type
    FROM clustered
    ORDER BY saves DESC
    LIMIT 900;  -- Max possible with 30x30 grid
END;
$function$;
