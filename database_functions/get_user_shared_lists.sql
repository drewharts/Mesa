-- ============================================================================
-- FUNCTION: get_user_shared_lists
-- Purpose: Fetch all lists where user is a collaborator (not owner)
-- Returns lists shared with the user, including owner info AND collaborator photos
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
    average_location TEXT,
    owner_id TEXT,
    owner_name TEXT,
    owner_photo_url TEXT,
    user_role TEXT,
    added_at TIMESTAMPTZ,
    collaborator_photos TEXT[],
    collaborator_count BIGINT,
    description TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        pl.id AS list_id,
        pl.name,
        pl.is_public,
        pl.image,
        (SELECT COUNT(*) FROM place_list_items pli WHERE pli.list_id = pl.id) AS place_count,
        NULL::TEXT AS city,
        ST_AsText(pl.average_location) AS average_location,
        pl.user_id AS owner_id,
        u.full_name AS owner_name,
        u.profile_photo_url AS owner_photo_url,
        plc.role AS user_role,
        plc.added_at,
        -- Get array of collaborator profile photos (excluding current user, limit to 5)
        (
            SELECT ARRAY_AGG(collab_user.profile_photo_url)
            FROM (
                SELECT u2.profile_photo_url
                FROM place_list_collaborators plc2
                JOIN users u2 ON u2.id = plc2.user_id
                WHERE plc2.list_id = pl.id 
                AND plc2.user_id != p_user_id
                LIMIT 5
            ) collab_user
        ) AS collaborator_photos,
        -- Total collaborator count (excluding current user)
        (
            SELECT COUNT(*) 
            FROM place_list_collaborators plc3 
            WHERE plc3.list_id = pl.id 
            AND plc3.user_id != p_user_id
        ) AS collaborator_count,
        pl.description
    FROM place_list_collaborators plc
    JOIN place_lists pl ON pl.id = plc.list_id
    JOIN users u ON u.id = pl.user_id
    WHERE plc.user_id = p_user_id
    ORDER BY plc.added_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_user_shared_lists(TEXT) TO authenticated;
