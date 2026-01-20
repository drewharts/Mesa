-- ============================================================================
-- Function: search_places_by_types
-- ============================================================================
-- Returns paginated list of places matching specified category types within a bounding box
-- Includes latest review photo for consistent display with other popups
-- Used by KeywordResultsPopupView for keyword-based place searches
-- ============================================================================

CREATE OR REPLACE FUNCTION public.search_places_by_types(
    p_types TEXT[],
    p_north_lat DOUBLE PRECISION,
    p_south_lat DOUBLE PRECISION,
    p_east_lng DOUBLE PRECISION,
    p_west_lng DOUBLE PRECISION,
    p_limit INT DEFAULT 20,
    p_offset INT DEFAULT 0
)
RETURNS TABLE (
    place_id TEXT,
    name TEXT,
    coordinate GEOMETRY,
    latest_review_photo TEXT,
    categories TEXT[]
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.id::TEXT AS place_id,
        p.name,
        p.location AS coordinate,
        get_latest_review_photo(p.id::TEXT) AS latest_review_photo,
        p.categories
    FROM places p
    WHERE p.categories && p_types
      AND ST_Within(
          p.location,
          ST_MakeEnvelope(p_west_lng, p_south_lat, p_east_lng, p_north_lat, 4326)
      )
    ORDER BY p.name
    LIMIT p_limit
    OFFSET p_offset;
END;
$$;
