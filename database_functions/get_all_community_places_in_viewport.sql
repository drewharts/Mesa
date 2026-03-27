-- ============================================================================
-- Function: get_all_community_places_in_viewport
-- ============================================================================
-- Returns ALL community places in viewport WITHOUT density filtering
-- Used specifically for "Places in View" popup to show every place
-- regardless of zoom level
-- 
-- Unlike get_community_places_in_viewport, this function does NOT use
-- grid-based clustering - it returns every place in the viewport
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_all_community_places_in_viewport(
    p_user_id text, 
    p_min_lon double precision, 
    p_min_lat double precision, 
    p_max_lon double precision, 
    p_max_lat double precision
)
RETURNS TABLE(id text, name text, latitude double precision, longitude double precision, save_count bigint, place_type text)
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
    -- Join with places table to get location and details (NO grid clustering)
    places_with_location AS (
        SELECT 
            p.id::text AS place_id,
            p.name AS place_name,
            ST_Y(p.location::geometry) AS lat,
            ST_X(p.location::geometry) AS lon,
            cs.save_count AS saves,
            -- Use FIRST category (most specific) - Google puts generic types last
            COALESCE(
                p.user_corrected_category,
                -- Try first non-generic category
                (SELECT cat FROM unnest(p.categories) AS cat
                 WHERE LOWER(cat) NOT IN ('establishment', 'point_of_interest', 'food', 'store', 'place', 'health')
                 LIMIT 1),
                -- Fallback to first category if all are generic
                p.categories[1],
                -- Ultimate fallback
                'Place'
            ) AS ptype
        FROM community_saves cs
        JOIN places p ON cs.place_id = p.id::text
        WHERE ST_Intersects(p.location, v_bbox)
    )
    SELECT 
        place_id AS id,
        place_name AS name,
        lat AS latitude,
        lon AS longitude,
        saves AS save_count,
        ptype AS place_type
    FROM places_with_location
    ORDER BY saves DESC;
END;
$function$;
