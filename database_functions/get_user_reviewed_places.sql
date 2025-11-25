-- ============================================================================
-- Function: get_user_reviewed_places
-- ============================================================================
-- Returns paginated list of places reviewed by a user
-- Uses server-side pagination like external_places for better performance
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
    SELECT DISTINCT ON (r.place_id)
        r.place_id::text,
        p.name,
        p.location AS coordinate,
        get_latest_review_photo(r.place_id::text) AS latest_review_photo
    FROM reviews r
    JOIN places p ON r.place_id = p.id
    WHERE r.user_id = p_user_id::uuid
    ORDER BY r.place_id, r.timestamp DESC, r.id DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$function$;

