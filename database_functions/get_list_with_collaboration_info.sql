-- ============================================================================
-- FUNCTION: get_list_with_collaboration_info
-- Purpose: Get list details including collaboration status for current user
-- Note: Using TEXT for IDs to match existing schema
-- ============================================================================

CREATE OR REPLACE FUNCTION get_list_with_collaboration_info(
    p_list_id TEXT,
    p_user_id TEXT
)
RETURNS TABLE (
    list_id TEXT,
    name TEXT,
    is_public BOOLEAN,
    image TEXT,
    city TEXT,
    owner_id TEXT,
    owner_name TEXT,
    owner_photo_url TEXT,
    is_owner BOOLEAN,
    is_collaborator BOOLEAN,
    user_role TEXT,
    collaborator_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pl.id AS list_id,
        pl.name,
        pl.is_public,
        pl.image,
        pl.city,
        pl.user_id AS owner_id,
        u.full_name AS owner_name,
        u.profile_photo_url AS owner_photo_url,
        (pl.user_id = p_user_id) AS is_owner,
        EXISTS (
            SELECT 1 FROM place_list_collaborators plc 
            WHERE plc.list_id = pl.id AND plc.user_id = p_user_id
        ) AS is_collaborator,
        (
            SELECT plc.role FROM place_list_collaborators plc 
            WHERE plc.list_id = pl.id AND plc.user_id = p_user_id
            LIMIT 1
        ) AS user_role,
        (
            SELECT COUNT(*) FROM place_list_collaborators plc 
            WHERE plc.list_id = pl.id
        ) AS collaborator_count
    FROM place_lists pl
    JOIN users u ON u.id = pl.user_id
    WHERE pl.id = p_list_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_list_with_collaboration_info(TEXT, TEXT) TO authenticated;

