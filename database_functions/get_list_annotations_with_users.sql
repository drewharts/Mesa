-- ============================================================================
-- Function: get_list_annotations_with_users
-- ============================================================================
-- Returns map annotations for a specific place list with grid-based clustering
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

CREATE OR REPLACE FUNCTION public.get_list_annotations_with_users(
    p_user_id text,
    p_list_id text,
    p_min_lon double precision,
    p_min_lat double precision,
    p_max_lon double precision,
    p_max_lat double precision,
    p_grid_cells_across integer DEFAULT 25
)
RETURNS TABLE(id text, name text, coordinate geometry, user_ids text[], place_type text)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $function$
DECLARE
    v_bbox geometry;
    v_grid_size_lon double precision;
    v_grid_size_lat double precision;
BEGIN
    v_bbox := get_bounding_box(p_min_lon, p_min_lat, p_max_lon, p_max_lat);
    
    v_grid_size_lon := (p_max_lon - p_min_lon) / p_grid_cells_across;
    v_grid_size_lat := (p_max_lat - p_min_lat) / p_grid_cells_across;

    RETURN QUERY
    WITH list_annotations AS (
        SELECT 
            pli.place_id AS id,
            p.name,
            p.location AS coordinate,
            array_agg(COALESCE(pli.added_by, pl.user_id) ORDER BY COALESCE(pli.added_by, pl.user_id)) AS user_ids,
            COALESCE(
                (SELECT cat FROM unnest(p.categories) AS cat
                 WHERE LOWER(cat) NOT IN ('establishment', 'point_of_interest', 'food', 'store', 'place', 'health')
                 LIMIT 1),
                p.categories[1],
                'Place'
            ) AS place_type
        FROM place_list_items pli
        INNER JOIN place_lists pl ON pli.list_id = pl.id
        INNER JOIN places p ON pli.place_id = p.id
        WHERE pli.list_id = p_list_id
        AND ST_Intersects(p.location, v_bbox)
        GROUP BY pli.place_id, p.name, p.location, p.categories
    ),
    aggregated AS (
        SELECT 
            a.id AS place_id,
            a.name AS place_name,
            a.coordinate AS place_coordinate,
            a.place_type AS ptype,
            array_agg(DISTINCT u ORDER BY u) AS all_user_ids,
            ST_SnapToGrid(a.coordinate, v_grid_size_lon, v_grid_size_lat) AS grid_cell
        FROM list_annotations a
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
