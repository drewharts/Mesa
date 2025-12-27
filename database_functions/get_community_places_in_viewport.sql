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
-- Includes minimum distance filtering to prevent marker overcrowding
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_community_places_in_viewport(
    p_user_id text, 
    p_min_lon double precision, 
    p_min_lat double precision, 
    p_max_lon double precision, 
    p_max_lat double precision,
    p_limit integer DEFAULT 500,
    p_min_distance_meters double precision DEFAULT 100  -- Min distance between markers
)
RETURNS TABLE(id text, name text, latitude double precision, longitude double precision, save_count bigint, place_type text)
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
        )
        -- Join with places table to get location and details
        SELECT 
            p.id::text AS place_id,
            p.name AS place_name,
            p.location AS place_location,
            ST_Y(p.location::geometry) AS lat,
            ST_X(p.location::geometry) AS lon,
            cs.save_count AS saves,
            COALESCE(p.categories[1], 'Place') AS ptype
        FROM community_saves cs
        JOIN places p ON cs.place_id = p.id::text
        WHERE ST_Intersects(p.location, v_bbox)
        ORDER BY cs.save_count DESC
        LIMIT p_limit * 3
    LOOP
        v_is_far_enough := true;
        
        FOREACH v_loc IN ARRAY v_selected_locations
        LOOP
            IF ST_DWithin(
                v_result.place_location::geography,
                v_loc::geography,
                p_min_distance_meters
            ) THEN
                v_is_far_enough := false;
                EXIT;
            END IF;
        END LOOP;
        
        IF v_is_far_enough THEN
            v_selected_locations := array_append(v_selected_locations, v_result.place_location);
            
            id := v_result.place_id;
            name := v_result.place_name;
            latitude := v_result.lat;
            longitude := v_result.lon;
            save_count := v_result.saves;
            place_type := v_result.ptype;
            RETURN NEXT;
            
            IF array_length(v_selected_locations, 1) >= p_limit THEN
                EXIT;
            END IF;
        END IF;
    END LOOP;
END;
$function$;
