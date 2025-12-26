-- ============================================================================
-- Function: get_user_reviewed_places
-- ============================================================================
-- Returns paginated list of places reviewed by a user
-- Uses CTE to separate DISTINCT ON from pagination ORDER BY
-- Orders by most recent review timestamp for stable pagination
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
    WITH distinct_places AS (
        -- First, get distinct place_ids ordered by most recent review
    SELECT DISTINCT ON (r.place_id)
            r.place_id,
            r.timestamp
        FROM reviews r
        WHERE r.user_id = p_user_id  -- user_id is TEXT, not UUID
        ORDER BY r.place_id, r.timestamp DESC
    )
    SELECT 
        dp.place_id::text,
        p.name,
        p.location AS coordinate,
        get_latest_review_photo(dp.place_id::text) AS latest_review_photo
    FROM distinct_places dp
    JOIN places p ON dp.place_id = p.id
    ORDER BY dp.timestamp DESC, dp.place_id ASC  -- Added place_id tiebreaker for truly stable pagination
    LIMIT p_limit
    OFFSET p_offset;
END;
$function$;
