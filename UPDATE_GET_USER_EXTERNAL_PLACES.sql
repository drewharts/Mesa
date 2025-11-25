-- Update the get_user_external_places function to include external_place_id
-- This is needed for refreshing TikTok thumbnails from tiles
-- Updated to join with places table since external_places no longer has name/coordinates

DROP FUNCTION IF EXISTS get_user_external_places(text, integer, integer);

CREATE OR REPLACE FUNCTION get_user_external_places(
    p_user_id text,
    p_limit integer,
    p_offset integer
)
RETURNS TABLE (
    place_id text,
    name text,
    coordinate geometry,
    latest_review_photo text,
    external_place_id text  -- ✅ Added this field
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ep.place_id,
        p.name,  -- ✅ Join with places table for name
        p.location AS coordinate,  -- ✅ Join with places table for coordinates
        get_latest_review_photo(ep.place_id) AS latest_review_photo,
        ep.id AS external_place_id  -- ✅ Return the external_places.id
    FROM external_places ep
    JOIN places p ON ep.place_id = p.id  -- ✅ Join with places table
    WHERE ep.user_id = p_user_id
    ORDER BY ep.added_at DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

-- Usage: SELECT * FROM get_user_external_places('user-uuid-here', 8, 0);

