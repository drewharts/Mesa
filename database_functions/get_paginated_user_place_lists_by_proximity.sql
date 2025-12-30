-- ============================================================================
-- Function: get_paginated_user_place_lists_by_proximity
-- ============================================================================
-- Returns user's owned place lists sorted by proximity to given location
-- Lists WITH location are sorted by proximity (closest first)
-- Lists WITHOUT location appear at the end (sorted by created_at desc)
-- Includes collaborator count and photos for displaying shared status
-- ============================================================================

CREATE OR REPLACE FUNCTION get_paginated_user_place_lists_by_proximity(
    p_user_id TEXT, 
    p_user_location geometry, 
    p_page INTEGER, 
    p_page_size INTEGER
)
RETURNS TABLE(
    list_id TEXT, 
    name TEXT, 
    average_location geometry, 
    is_public BOOLEAN, 
    image TEXT, 
    created_at TIMESTAMP WITHOUT TIME ZONE, 
    updated_at TIMESTAMP WITHOUT TIME ZONE, 
    distance_meters DOUBLE PRECISION, 
    place_count BIGINT,
    collaborator_count BIGINT,
    collaborator_photos TEXT[]
)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    RETURN QUERY
    -- Use a subquery with sort_order to combine lists with and without locations
    SELECT 
        combined.list_id,
        combined.name,
        combined.average_location,
        combined.is_public,
        combined.image,
        combined.created_at,
        combined.updated_at,
        combined.distance_meters,
        combined.place_count,
        combined.collaborator_count,
        combined.collaborator_photos
    FROM (
        -- Lists WITH average_location (sorted by proximity)
    SELECT 
        pl.id::TEXT AS list_id,
        pl.name,
        pl.average_location,
        pl.is_public,
        pl.image,
        pl.created_at,
        pl.updated_at,
        ST_Distance(pl.average_location, p_user_location) AS distance_meters,
            (SELECT COUNT(*) FROM place_list_items pli WHERE pli.list_id = pl.id) AS place_count,
            (SELECT COUNT(*) FROM place_list_collaborators plc WHERE plc.list_id = pl.id) AS collaborator_count,
            (
                SELECT ARRAY_AGG(collab_photos.profile_photo_url)
                FROM (
                    SELECT u.profile_photo_url
                    FROM place_list_collaborators plc
                    JOIN users u ON u.id = plc.user_id
                    WHERE plc.list_id = pl.id
                    LIMIT 5
                ) collab_photos
            ) AS collaborator_photos,
            0 AS sort_order  -- Lists with location come first
    FROM place_lists pl
    WHERE pl.user_id = p_user_id
        AND pl.average_location IS NOT NULL
        
        UNION ALL
        
        -- Lists WITHOUT average_location (empty/new lists, sorted by created_at)
        SELECT 
            pl.id::TEXT AS list_id,
            pl.name,
            pl.average_location,
            pl.is_public,
            pl.image,
            pl.created_at,
            pl.updated_at,
            NULL::DOUBLE PRECISION AS distance_meters,  -- No distance for lists without location
            (SELECT COUNT(*) FROM place_list_items pli WHERE pli.list_id = pl.id) AS place_count,
            (SELECT COUNT(*) FROM place_list_collaborators plc WHERE plc.list_id = pl.id) AS collaborator_count,
            (
                SELECT ARRAY_AGG(collab_photos.profile_photo_url)
                FROM (
                    SELECT u.profile_photo_url
                    FROM place_list_collaborators plc
                    JOIN users u ON u.id = plc.user_id
                    WHERE plc.list_id = pl.id
                    LIMIT 5
                ) collab_photos
            ) AS collaborator_photos,
            1 AS sort_order  -- Lists without location come after
        FROM place_lists pl
        WHERE pl.user_id = p_user_id
            AND pl.average_location IS NULL
    ) combined
    ORDER BY 
        combined.sort_order ASC,  -- Lists with location first
        CASE WHEN combined.sort_order = 0 THEN combined.distance_meters ELSE NULL END ASC,  -- Then by proximity
        CASE WHEN combined.sort_order = 1 THEN combined.created_at ELSE NULL END DESC NULLS LAST  -- Or by creation date for new lists
    OFFSET (p_page - 1) * p_page_size
    LIMIT p_page_size;
END;
$function$;

GRANT EXECUTE ON FUNCTION get_paginated_user_place_lists_by_proximity(TEXT, geometry, INTEGER, INTEGER) TO authenticated;
