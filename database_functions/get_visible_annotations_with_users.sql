-- ============================================================================
-- Function: get_visible_annotations_with_users
-- ============================================================================
-- Enterprise-grade grid-based clustering for map markers
-- Uses ST_SnapToGrid for O(n) performance (same approach as Google Maps/Mapbox)
-- 
-- How it works:
-- 1. Divides viewport into a grid (default 25x25 cells)
-- 2. Snaps all points to grid cells
-- 3. Picks ONE representative per cell (prioritizing places with more savers)
-- 4. Result: consistent marker density at any zoom level
--
-- Performance: O(n) vs O(n²) for distance-based filtering
-- Updated: Now includes place_type derived from categories
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_visible_annotations_with_users(
    p_user_id text, 
    p_min_lon double precision, 
    p_min_lat double precision, 
    p_max_lon double precision, 
    p_max_lat double precision,
    p_grid_cells_across integer DEFAULT 25
)
RETURNS TABLE(id text, name text, coordinate geometry, user_ids text[], place_type text)
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
    
    v_grid_size_lon := (p_max_lon - p_min_lon) / p_grid_cells_across;
    v_grid_size_lat := (p_max_lat - p_min_lat) / p_grid_cells_across;

    RETURN QUERY
    WITH all_annotations AS (
        SELECT ann.id, ann.name, ann.coordinate, ann.user_ids, ann.place_type
        FROM get_my_places_annotations(v_user_friends, v_bbox) ann
        UNION ALL
        SELECT ann.id, ann.name, ann.coordinate, ann.user_ids, ann.place_type
        FROM get_favorites_annotations(v_user_friends, v_bbox) ann
        UNION ALL
        SELECT ann.id, ann.name, ann.coordinate, ann.user_ids, ann.place_type
        FROM get_external_places_annotations(v_user_friends, v_bbox) ann
        UNION ALL
        SELECT ann.id, ann.name, ann.coordinate, ann.user_ids, ann.place_type
        FROM get_list_places_annotations(v_user_friends, v_bbox, p_user_id) ann
        UNION ALL
        SELECT ann.id, ann.name, ann.coordinate, ann.user_ids, ann.place_type
        FROM get_reviewed_places_annotations(v_user_friends, v_bbox) ann
        UNION ALL
        SELECT ann.id, ann.name, ann.coordinate, ann.user_ids, ann.place_type
        FROM get_saved_list_places_annotations(p_user_id, v_bbox) ann
    ),
    aggregated AS (
        SELECT 
            a.id AS place_id,
            a.name AS place_name,
            a.coordinate AS place_coordinate,
            a.place_type AS ptype,
            array_agg(DISTINCT u ORDER BY u) AS all_user_ids,
            ST_SnapToGrid(a.coordinate, v_grid_size_lon, v_grid_size_lat) AS grid_cell
        FROM all_annotations a
        CROSS JOIN LATERAL unnest(a.user_ids) AS u
        GROUP BY a.id, a.name, a.coordinate, a.place_type
    ),
    clustered AS (
        SELECT DISTINCT ON (grid_cell)
            place_id,
            place_name,
            place_coordinate,
            all_user_ids,
            ptype
        FROM aggregated
        ORDER BY grid_cell, array_length(all_user_ids, 1) DESC NULLS LAST
    )
    SELECT 
        place_id AS id,
        place_name AS name,
        place_coordinate AS coordinate,
        all_user_ids AS user_ids,
        ptype AS place_type
    FROM clustered
    LIMIT 625;
END;
$function$;
