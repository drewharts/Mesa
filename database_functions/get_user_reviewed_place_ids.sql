-- ============================================================================
-- FUNCTION: get_user_reviewed_place_ids
-- Purpose: Given a user and list of place IDs, return which ones they've reviewed
-- Used for efficient "show only unvisited" filtering
-- ============================================================================

CREATE OR REPLACE FUNCTION get_user_reviewed_place_ids(
    p_user_id TEXT,
    p_place_ids TEXT[]
)
RETURNS TEXT[] AS $$
BEGIN
    RETURN ARRAY(
        SELECT DISTINCT r.place_id
        FROM reviews r
        WHERE r.user_id = p_user_id
        AND r.place_id = ANY(p_place_ids)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_user_reviewed_place_ids(TEXT, TEXT[]) TO authenticated;

