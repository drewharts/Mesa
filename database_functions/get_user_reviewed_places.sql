-- ============================================================================
-- Function: get_user_reviewed_places
-- ============================================================================
-- Returns paginated list of distinct places reviewed by a user
-- Uses GROUP BY for clean deduplication (simpler than DISTINCT ON)
-- Orders by most recent review timestamp for each place
-- Note: user_id column is TEXT (not UUID) - do not cast
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_user_reviewed_places(
    p_user_id text,
    p_limit integer,
    p_offset integer
)
RETURNS TABLE(
    place_id text,
    name text,
    coordinate geometry,
    latest_review_photo text
)
LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        r.place_id::text,
        p.name,
        p.location AS coordinate,
        get_latest_review_photo(r.place_id::text) AS latest_review_photo
    FROM reviews r
    JOIN places p ON r.place_id = p.id
    WHERE r.user_id = p_user_id
    GROUP BY r.place_id, p.name, p.location
    ORDER BY MAX(r.timestamp) DESC, r.place_id ASC
    LIMIT p_limit
    OFFSET p_offset;
END;
$function$;
