-- ============================================================================
-- Function: get_keyword_annotations_with_users
-- ============================================================================
-- Returns map annotations for keyword search results (filtered by category types)
-- with user_ids from save sources for profile picture composites.
--
-- Unlike other annotation queries that start from a save-source table,
-- this starts from the places table (filtered by categories) and LEFT JOINs
-- save sources. Unsaved places still appear with user_ids = '{}' so they
-- fall through to emoji display.
--
-- Uses ST_SnapToGrid for O(n) grid-based clustering (same as other annotation RPCs)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_keyword_annotations_with_users(
    p_user_id text,
    p_types text[],
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
    WITH matching_places AS (
        SELECT
            p.id::text AS place_id,
            p.name AS place_name,
            p.location AS place_coordinate,
            COALESCE(
                (SELECT cat FROM unnest(p.categories) AS cat
                 WHERE LOWER(cat) NOT IN ('establishment', 'point_of_interest', 'food', 'store', 'place', 'health')
                 LIMIT 1),
                p.categories[1],
                'Place'
            ) AS ptype
        FROM places p
        WHERE p.categories && p_types
        AND ST_Intersects(p.location, v_bbox)
    ),
    place_savers AS (
        SELECT mp.place_id, mp.user_id
        FROM matching_places m
        JOIN my_places mp ON mp.place_id = m.place_id
        WHERE mp.user_id = ANY(v_user_friends)

        UNION

        SELECT f.place_id, f.user_id
        FROM matching_places m
        JOIN favorites f ON f.place_id = m.place_id
        WHERE f.user_id = ANY(v_user_friends)

        UNION

        SELECT r.place_id::text, r.user_id
        FROM matching_places m
        JOIN reviews r ON r.place_id::text = m.place_id
        WHERE r.user_id = ANY(v_user_friends)

        UNION

        SELECT pli.place_id, COALESCE(pli.added_by, pl.user_id)
        FROM matching_places m
        JOIN place_list_items pli ON pli.place_id = m.place_id
        JOIN place_lists pl ON pl.id = pli.list_id
        WHERE (pl.user_id = ANY(v_user_friends) OR pli.added_by = ANY(v_user_friends))

        UNION

        SELECT ep.place_id, ep.user_id
        FROM matching_places m
        JOIN external_places ep ON ep.place_id = m.place_id
        WHERE ep.user_id = ANY(v_user_friends)
    ),
    with_users AS (
        SELECT
            m.place_id,
            m.place_name,
            m.place_coordinate,
            m.ptype,
            COALESCE(
                array_agg(DISTINCT ps.user_id ORDER BY ps.user_id) FILTER (WHERE ps.user_id IS NOT NULL),
                '{}'::text[]
            ) AS all_user_ids
        FROM matching_places m
        LEFT JOIN place_savers ps ON ps.place_id = m.place_id
        GROUP BY m.place_id, m.place_name, m.place_coordinate, m.ptype
    ),
    gridded AS (
        SELECT
            w.place_id,
            w.place_name,
            w.place_coordinate,
            w.ptype,
            w.all_user_ids,
            ST_SnapToGrid(w.place_coordinate, v_grid_size_lon, v_grid_size_lat) AS grid_cell
        FROM with_users w
    ),
    clustered AS (
        SELECT DISTINCT ON (grid_cell)
            place_id,
            place_name,
            place_coordinate,
            all_user_ids,
            ptype
        FROM gridded
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
