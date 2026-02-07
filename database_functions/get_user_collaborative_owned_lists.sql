-- ============================================================================
-- FUNCTION: get_user_collaborative_owned_lists
-- Purpose: Fetch all lists OWNED by user that have collaborators
-- Returns owned lists with collaborators (not paginated - for Shared filter)
-- Note: Using TEXT for IDs to match existing schema
-- ============================================================================

CREATE OR REPLACE FUNCTION get_user_collaborative_owned_lists(p_user_id TEXT)
RETURNS TABLE (
    list_id TEXT,
    name TEXT,
    is_public BOOLEAN,
    image TEXT,
    place_count BIGINT,
    city TEXT,
    average_location TEXT,
    collaborator_photos TEXT[],
    collaborator_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        pl.id AS list_id,
        pl.name,
        pl.is_public,
        pl.image AS image,
        (SELECT COUNT(*) FROM place_list_items pli WHERE pli.list_id = pl.id) AS place_count,
        NULL::TEXT AS city,
        ST_AsText(pl.average_location) AS average_location,
        -- Get array of collaborator profile photos (limit to 5)
        (
            SELECT ARRAY_AGG(collab_user.profile_photo_url)
            FROM (
                SELECT u2.profile_photo_url
                FROM place_list_collaborators plc2
                JOIN users u2 ON u2.id = plc2.user_id
                WHERE plc2.list_id = pl.id
                ORDER BY plc2.added_at ASC
                LIMIT 5
            ) collab_user
        ) AS collaborator_photos,
        -- Total collaborator count
        (
            SELECT COUNT(*) 
            FROM place_list_collaborators plc3 
            WHERE plc3.list_id = pl.id
        ) AS collaborator_count
    FROM place_lists pl
    WHERE pl.user_id = p_user_id
    -- Only return lists that have at least one collaborator
    AND EXISTS (
        SELECT 1 FROM place_list_collaborators plc 
        WHERE plc.list_id = pl.id
    )
    ORDER BY pl.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_user_collaborative_owned_lists(TEXT) TO authenticated;

