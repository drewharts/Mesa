-- ============================================================================
-- Function: get_paginated_user_place_lists_by_proximity
-- ============================================================================
-- Returns user's owned place lists sorted by proximity to given location
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
    SELECT 
        pl.id AS list_id,
        pl.name,
        pl.average_location,
        pl.is_public,
        pl.image,
        pl.created_at,
        pl.updated_at,
        ST_Distance(pl.average_location, p_user_location) AS distance_meters,
        (SELECT COUNT(*) FROM place_list_items pli WHERE pli.list_id = pl.id) AS place_count,
        -- Collaborator count
        (
            SELECT COUNT(*) 
            FROM place_list_collaborators plc 
            WHERE plc.list_id = pl.id
        ) AS collaborator_count,
        -- Collaborator photos (up to 5)
        (
            SELECT ARRAY_AGG(collab_photos.profile_photo_url)
            FROM (
                SELECT u.profile_photo_url
                FROM place_list_collaborators plc
                JOIN users u ON u.id = plc.user_id
                WHERE plc.list_id = pl.id
                LIMIT 5
            ) collab_photos
        ) AS collaborator_photos
    FROM place_lists pl
    WHERE pl.user_id = p_user_id
        AND pl.average_location IS NOT NULL
    ORDER BY ST_Distance(pl.average_location, p_user_location) ASC
    OFFSET (p_page - 1) * p_page_size
    LIMIT p_page_size;
END;
$function$;

GRANT EXECUTE ON FUNCTION get_paginated_user_place_lists_by_proximity(TEXT, geometry, INTEGER, INTEGER) TO authenticated;
