-- ============================================================================
-- Function: search_user_place_lists
-- ============================================================================
-- Searches user's place lists by name (server-side)
-- Returns all matching lists regardless of pagination
-- Includes both lists with and without places
-- Includes collaborator information for displaying shared status
-- ============================================================================

CREATE OR REPLACE FUNCTION search_user_place_lists(
    p_user_id TEXT,
    p_search_term TEXT,
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE(
    list_id TEXT,
    name TEXT,
    average_location TEXT,
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
        pl.id::TEXT AS list_id,
        pl.name,
        ST_AsText(pl.average_location) AS average_location,
        pl.is_public,
        pl.image,
        pl.created_at,
        pl.updated_at,
        NULL::DOUBLE PRECISION AS distance_meters,
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
        ) AS collaborator_photos
    FROM place_lists pl
    WHERE pl.user_id = p_user_id
        AND pl.name ILIKE '%' || p_search_term || '%'
    ORDER BY pl.name ASC
    LIMIT p_limit;
END;
$function$;

GRANT EXECUTE ON FUNCTION search_user_place_lists(TEXT, TEXT, INTEGER) TO authenticated;
