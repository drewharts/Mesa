-- ============================================================================
-- FUNCTION: get_list_collaborators
-- Purpose: Fetch all collaborators for a list with user details
-- Note: Using TEXT for IDs to match existing schema
-- ============================================================================

CREATE OR REPLACE FUNCTION get_list_collaborators(p_list_id TEXT)
RETURNS TABLE (
    id TEXT,
    user_id TEXT,
    role TEXT,
    user_name TEXT,
    profile_photo_url TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        plc.id,
        plc.user_id,
        plc.role,
        u.full_name AS user_name,
        u.profile_photo_url
    FROM place_list_collaborators plc
    JOIN users u ON u.id = plc.user_id
    WHERE plc.list_id = p_list_id
    ORDER BY plc.added_at ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_list_collaborators(TEXT) TO authenticated;
