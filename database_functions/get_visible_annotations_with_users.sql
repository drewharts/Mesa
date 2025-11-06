-- ============================================================================
-- Function: get_visible_annotations_with_users
-- ============================================================================
-- Returns place annotations for map markers within a geographic viewport
-- Combines places from multiple sources (my_places, favorites, external_places,
-- place_list_items, and reviewed places) for the user and their followed users
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_visible_annotations_with_users(
    p_user_id text, 
    p_min_lon double precision, 
    p_min_lat double precision, 
    p_max_lon double precision, 
    p_max_lat double precision
)
RETURNS TABLE(id text, name text, coordinate geometry, user_ids text[])
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
        SELECT ann.id, ann.name, ann.coordinate, ann.user_ids
        FROM get_my_places_annotations(v_user_friends, v_bbox) ann

        UNION ALL

        SELECT ann.id, ann.name, ann.coordinate, ann.user_ids
        FROM get_favorites_annotations(v_user_friends, v_bbox) ann

        UNION ALL

        -- External Places (TikTok) – now uses correct `location` column
        SELECT ann.id, ann.name, ann.coordinate, ann.user_ids
        FROM get_external_places_annotations(v_user_friends, v_bbox) ann

        UNION ALL

        SELECT ann.id, ann.name, ann.coordinate, ann.user_ids
        FROM get_list_places_annotations(v_user_friends, v_bbox) ann

        UNION ALL

        SELECT ann.id, ann.name, ann.coordinate, ann.user_ids
        FROM get_reviewed_places_annotations(v_user_friends, v_bbox) ann
    )
    SELECT DISTINCT ON (ann.id)
           ann.id,
           ann.name,
           ann.coordinate,
           array_agg(DISTINCT u ORDER BY u) AS user_ids
    FROM all_annotations ann
    CROSS JOIN LATERAL unnest(ann.user_ids) AS u
    GROUP BY ann.id, ann.name, ann.coordinate
    LIMIT 1000;
END;
$function$;
