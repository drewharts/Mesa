-- ============================================================================
-- FUNCTION: get_user_shared_lists
-- Purpose: Fetch all lists where user is a collaborator (not owner)
-- Returns lists shared with the user, including owner info
-- Note: Using TEXT for IDs to match existing schema
-- ============================================================================

CREATE OR REPLACE FUNCTION get_user_shared_lists(p_user_id TEXT)
RETURNS TABLE (
    list_id TEXT,
    name TEXT,
    is_public BOOLEAN,
    image TEXT,
    place_count BIGINT,
    city TEXT,
    owner_id TEXT,
    owner_name TEXT,
    owner_photo_url TEXT,
    user_role TEXT,
    added_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pl.id AS list_id,
        pl.name,
        pl.is_public,
        pl.image,
        (SELECT COUNT(*) FROM place_list_items WHERE list_id = pl.id) AS place_count,
        NULL::TEXT AS city,  -- place_lists doesn't have city column
        pl.user_id AS owner_id,
        u.full_name AS owner_name,
        u.profile_photo_url AS owner_photo_url,
        plc.role AS user_role,
        plc.added_at
    FROM place_list_collaborators plc
    JOIN place_lists pl ON pl.id = plc.list_id
    JOIN users u ON u.id = pl.user_id
    WHERE plc.user_id = p_user_id
    ORDER BY plc.added_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_user_shared_lists(TEXT) TO authenticated;
