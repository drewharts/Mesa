-- ============================================================================
-- Function: get_visible_annotations_with_users
-- ============================================================================
-- Returns place annotations for map markers within a geographic viewport
-- Combines places from multiple sources (my_places, favorites, external_places,
-- place_list_items, and reviewed places) for the user and their followed users
-- 
-- Includes minimum distance filtering to prevent marker overcrowding
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_visible_annotations_with_users(
    p_user_id text, 
    p_min_lon double precision, 
    p_min_lat double precision, 
    p_max_lon double precision, 
    p_max_lat double precision,
    p_limit integer DEFAULT 500,
    p_min_distance_meters double precision DEFAULT 50  -- Min distance between markers
)
RETURNS TABLE(id text, name text, coordinate geometry, user_ids text[])
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_user_friends text[];
    v_bbox geometry;
    v_result RECORD;
    v_selected_locations geometry[] := ARRAY[]::geometry[];
    v_is_far_enough boolean;
    v_loc geometry;
BEGIN
    v_user_friends := ARRAY(SELECT * FROM get_user_and_friends(p_user_id));
    v_bbox := get_bounding_box(p_min_lon, p_min_lat, p_max_lon, p_max_lat);

    FOR v_result IN
        WITH all_annotations AS (
            SELECT ann.id, ann.name, ann.coordinate, ann.user_ids
            FROM get_my_places_annotations(v_user_friends, v_bbox) ann

            UNION ALL

            SELECT ann.id, ann.name, ann.coordinate, ann.user_ids
            FROM get_favorites_annotations(v_user_friends, v_bbox) ann

            UNION ALL

            SELECT ann.id, ann.name, ann.coordinate, ann.user_ids
            FROM get_external_places_annotations(v_user_friends, v_bbox) ann

            UNION ALL

            SELECT ann.id, ann.name, ann.coordinate, ann.user_ids
            FROM get_list_places_annotations(v_user_friends, v_bbox) ann

            UNION ALL

            SELECT ann.id, ann.name, ann.coordinate, ann.user_ids
            FROM get_reviewed_places_annotations(v_user_friends, v_bbox) ann
        ),
        aggregated AS (
            SELECT DISTINCT ON (ann.id)
                   ann.id AS place_id,
                   ann.name AS place_name,
                   ann.coordinate AS place_coordinate,
                   array_agg(DISTINCT u ORDER BY u) AS all_user_ids
            FROM all_annotations ann
            CROSS JOIN LATERAL unnest(ann.user_ids) AS u
            GROUP BY ann.id, ann.name, ann.coordinate
        )
        SELECT * FROM aggregated
        ORDER BY array_length(all_user_ids, 1) DESC NULLS LAST  -- Prioritize places with more savers
        LIMIT p_limit * 3  -- Fetch extra to account for density filtering
    LOOP
        v_is_far_enough := true;
        
        -- Check distance against all already-selected locations
        FOREACH v_loc IN ARRAY v_selected_locations
        LOOP
            IF ST_DWithin(
                v_result.place_coordinate::geography,
                v_loc::geography,
                p_min_distance_meters
            ) THEN
                v_is_far_enough := false;
                EXIT;
            END IF;
        END LOOP;
        
        -- If far enough from all existing markers, include this one
        IF v_is_far_enough THEN
            v_selected_locations := array_append(v_selected_locations, v_result.place_coordinate);
            
            id := v_result.place_id;
            name := v_result.place_name;
            coordinate := v_result.place_coordinate;
            user_ids := v_result.all_user_ids;
            RETURN NEXT;
            
            -- Stop if we've reached the limit
            IF array_length(v_selected_locations, 1) >= p_limit THEN
                EXIT;
            END IF;
        END IF;
    END LOOP;
END;
$function$;
