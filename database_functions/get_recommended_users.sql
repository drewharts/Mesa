-- ============================================================================
-- Function: get_recommended_users
-- ============================================================================
-- Returns recommended users ordered by total unique places count (most active
-- users first). Excludes the requesting user and users they already follow.
-- Returns user table columns so the response decodes directly to ProfileData.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_recommended_users(
    p_user_id TEXT,
    p_limit INT DEFAULT 15
)
RETURNS SETOF users
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $function$
BEGIN
    RETURN QUERY
    SELECT u.*
    FROM users u
    LEFT JOIN (
        -- Count unique places per user across all sources
        SELECT sub.user_id, COUNT(DISTINCT sub.place_id) AS total_places
        FROM (
            SELECT pl.user_id, pli.place_id
            FROM place_list_items pli
            INNER JOIN place_lists pl ON pl.id = pli.list_id

            UNION

            SELECT f.user_id, f.place_id
            FROM favorites f

            UNION

            SELECT r.user_id, r.place_id
            FROM reviews r

            UNION

            SELECT mp.user_id, mp.place_id
            FROM my_places mp
        ) sub
        GROUP BY sub.user_id
    ) pc ON pc.user_id = u.id
    WHERE u.id != p_user_id
      AND u.id NOT IN (
          SELECT f.following_id
          FROM following f
          WHERE f.follower_id = p_user_id
      )
    ORDER BY COALESCE(pc.total_places, 0) DESC
    LIMIT p_limit;
END;
$function$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_recommended_users(TEXT, INT) TO authenticated;
