-- ============================================================================
-- Function: get_all_friends_places_in_viewport
-- ============================================================================
-- Returns ALL friends/network places in viewport WITHOUT density filtering
-- Used specifically for "Places in View" popup to show every place
-- regardless of zoom level
-- 
-- Unlike get_visible_annotations_with_users, this function does NOT use
-- grid-based clustering - it returns every place in the viewport
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_all_friends_places_in_viewport(
    p_user_id text, 
    p_min_lon double precision, 
    p_min_lat double precision, 
    p_max_lon double precision, 
    p_max_lat double precision
)
RETURNS TABLE(id text, name text, coordinate geometry, user_ids text[], place_type text)
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_user_friends text[];
    v_bbox geometry;
BEGIN
    v_user_friends := ARRAY(SELECT * FROM get_user_and_friends(p_user_id));
    v_bbox := get_bounding_box(p_min_lon, p_min_lat, p_max_lon, p_max_lat);

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
        FROM get_list_places_annotations(v_user_friends, v_bbox) ann
        UNION ALL
        SELECT ann.id, ann.name, ann.coordinate, ann.user_ids, ann.place_type
        FROM get_reviewed_places_annotations(v_user_friends, v_bbox) ann
    ),
    -- Aggregate user_ids per place (NO grid clustering)
    aggregated AS (
        SELECT 
            a.id AS place_id,
            a.name AS place_name,
            a.coordinate AS place_coordinate,
            a.place_type AS ptype,
            array_agg(DISTINCT u ORDER BY u) AS all_user_ids
        FROM all_annotations a
        CROSS JOIN LATERAL unnest(a.user_ids) AS u
        GROUP BY a.id, a.name, a.coordinate, a.place_type
    )
    SELECT 
        place_id AS id,
        place_name AS name,
        place_coordinate AS coordinate,
        all_user_ids AS user_ids,
        ptype AS place_type
    FROM aggregated
    ORDER BY array_length(all_user_ids, 1) DESC NULLS LAST;
END;
$function$;
