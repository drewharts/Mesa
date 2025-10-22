-- ============================================================================
-- ADD REVIEWED PLACES TO MAP ANNOTATIONS
-- ============================================================================
-- This SQL script adds support for showing reviewed places on the map
-- Previously, the map only showed places that were saved/favorited/in lists
-- Now it also shows places that people have reviewed
--
-- Date: 2025-01-29
-- Issue: Friends' reviewed places (like Joseph's "Onigiri Tanakaya") weren't 
--        showing up on the map because we only queried my_places, favorites, 
--        external_places, and place_list_items
-- ============================================================================

-- ============================================================================
-- 1. CREATE NEW FUNCTION: get_reviewed_places_annotations
-- ============================================================================
-- This function fetches all places that users have reviewed within a bounding box
CREATE OR REPLACE FUNCTION get_reviewed_places_annotations(
    p_user_ids text[],
    p_bbox geometry
)
RETURNS TABLE (
    id text,
    name text,
    coordinate geometry,
    user_ids text[]
) AS $$
SELECT 
    r.place_id AS id,
    p.name,
    p.location AS coordinate,
    array_agg(DISTINCT r.user_id ORDER BY r.user_id) AS user_ids
FROM reviews r
INNER JOIN places p ON r.place_id = p.id
WHERE r.user_id = ANY(p_user_ids)
AND ST_Intersects(p.location, p_bbox)
GROUP BY r.place_id, p.name, p.location
$$ LANGUAGE sql STABLE;

-- ============================================================================
-- 2. UPDATE MAIN FUNCTION: get_visible_annotations_with_users
-- ============================================================================
-- Drop the old version
DROP FUNCTION IF EXISTS get_visible_annotations_with_users(text,double precision,double precision,double precision,double precision);

-- Recreate with reviewed places included
CREATE FUNCTION get_visible_annotations_with_users(
    p_user_id text,
    p_min_lon double precision,
    p_min_lat double precision,
    p_max_lon double precision,
    p_max_lat double precision
)
RETURNS TABLE (
    id text,
    name text,
    coordinate geometry,
    user_ids text[]
) AS $$
DECLARE
    v_user_friends text[];
    v_bbox geometry;
BEGIN
    -- Get the current user + everyone they follow
    v_user_friends := ARRAY(SELECT * FROM get_user_and_friends(p_user_id));
    
    -- Create bounding box from viewport coordinates
    v_bbox := get_bounding_box(p_min_lon, p_min_lat, p_max_lon, p_max_lat);
    
    RETURN QUERY
    WITH all_annotations AS (
        -- My Places (custom created places)
        SELECT ann.id, ann.name, ann.coordinate, ann.user_ids
        FROM get_my_places_annotations(v_user_friends, v_bbox) ann
        
        UNION ALL
        
        -- Favorites (saved places)
        SELECT ann.id, ann.name, ann.coordinate, ann.user_ids
        FROM get_favorites_annotations(v_user_friends, v_bbox) ann
        
        UNION ALL
        
        -- External Places (TikTok imports)
        SELECT ann.id, ann.name, ann.coordinate, ann.user_ids
        FROM get_external_places_annotations(v_user_friends, v_bbox) ann
        
        UNION ALL
        
        -- Place List Items (places in curated lists)
        SELECT ann.id, ann.name, ann.coordinate, ann.user_ids
        FROM get_list_places_annotations(v_user_friends, v_bbox) ann
        
        UNION ALL
        
        -- ✨ NEW: Reviewed Places (places that have been reviewed)
        SELECT ann.id, ann.name, ann.coordinate, ann.user_ids
        FROM get_reviewed_places_annotations(v_user_friends, v_bbox) ann
    )
    -- Aggregate all sources and deduplicate by place ID
    SELECT DISTINCT ON (ann.id)
        ann.id,
        ann.name,
        ann.coordinate,
        array_agg(DISTINCT u ORDER BY u) AS user_ids
    FROM all_annotations ann,
         LATERAL unnest(ann.user_ids) AS u
    GROUP BY ann.id, ann.name, ann.coordinate
    LIMIT 1000; -- Performance cap
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================================
-- TESTING THE CHANGES
-- ============================================================================
-- To verify the function works, run this query:
/*
-- Test with a specific user and NYC bounding box
SELECT 
    a.id,
    a.name,
    a.user_ids,
    ST_Y(a.coordinate) as latitude,
    ST_X(a.coordinate) as longitude
FROM get_visible_annotations_with_users(
    'YOUR_USER_ID_HERE',
    -74.1,  -- min_lon (west)
    40.6,   -- min_lat (south)
    -73.9,  -- max_lon (east)
    40.8    -- max_lat (north)
) a
ORDER BY a.name
LIMIT 20;
*/

-- ============================================================================
-- WHAT THIS FIXES
-- ============================================================================
-- Before: Only showed places that were explicitly saved/favorited/in lists
-- After: Also shows places that people have reviewed
--
-- Example: If Joseph reviews "Onigiri Tanakaya" but doesn't save it to 
--          favorites or a list, it will now show up on the map for people
--          who follow Joseph.
--
-- Impact: More complete view of friends' activity on the map
-- ============================================================================

