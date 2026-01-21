-- ============================================================================
-- Function: get_place_savers
-- ============================================================================
-- Returns ALL users who have "saved" a specific place through any method:
-- 1. Favorites (added to favorites)
-- 2. Place Lists (added to any list - uses added_by for proper attribution)
-- 3. External Places (saved a TikTok for this place)
-- 4. Reviews (reviewed the place)
--
-- Returns is_followed flag so UI can separate friends from non-friends.
-- Friends (followed users) appear first in results.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_place_savers(
    p_place_id TEXT,
    p_requesting_user_id TEXT DEFAULT NULL
)
RETURNS TABLE(
    user_id TEXT,
    full_name TEXT,
    profile_photo_url TEXT,
    is_followed BOOLEAN
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $function$
BEGIN
    RETURN QUERY
    WITH all_savers AS (
        -- 1. Users who favorited this place
        SELECT f.user_id
        FROM favorites f
        WHERE f.place_id = p_place_id

        UNION

        -- 2. Users who added this place to any list (use added_by for proper attribution)
        SELECT COALESCE(pli.added_by, pl.user_id) AS user_id
        FROM place_list_items pli
        INNER JOIN place_lists pl ON pli.list_id = pl.id
        WHERE pli.place_id = p_place_id

        UNION

        -- 3. Users who saved a TikTok for this place
        SELECT ep.user_id
        FROM external_places ep
        WHERE ep.place_id = p_place_id

        UNION

        -- 4. Users who reviewed this place
        SELECT r.user_id
        FROM reviews r
        WHERE r.place_id = p_place_id
    )
    SELECT
        u.id AS user_id,
        u.full_name,
        u.profile_photo_url,
        -- Check if requesting user follows this saver
        CASE
            WHEN p_requesting_user_id IS NULL THEN FALSE
            WHEN u.id = p_requesting_user_id THEN FALSE  -- Current user is not "followed"
            ELSE EXISTS (
                SELECT 1 FROM following f
                WHERE f.follower_id = p_requesting_user_id
                AND f.following_id = u.id
            )
        END AS is_followed
    FROM all_savers s
    INNER JOIN users u ON s.user_id = u.id
    GROUP BY u.id, u.full_name, u.profile_photo_url
    ORDER BY
        -- Put requesting user first
        CASE WHEN u.id = p_requesting_user_id THEN 0 ELSE 1 END,
        -- Then followed users
        CASE WHEN p_requesting_user_id IS NOT NULL AND EXISTS (
            SELECT 1 FROM following f
            WHERE f.follower_id = p_requesting_user_id
            AND f.following_id = u.id
        ) THEN 0 ELSE 1 END,
        -- Then alphabetically
        u.full_name;
END;
$function$;

-- Add comment for documentation
COMMENT ON FUNCTION public.get_place_savers(TEXT, TEXT) IS
'Returns ALL users who saved a place via favorites, lists, TikToks, or reviews.
Includes is_followed flag to separate friends from non-friends in UI.
Results ordered: current user first, then followed users, then others alphabetically.';
