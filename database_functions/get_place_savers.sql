-- ============================================================================
-- Function: get_place_savers
-- ============================================================================
-- Returns all users who have "saved" a specific place through any method:
-- 1. Favorites (added to favorites)
-- 2. Place Lists (added to any list - uses added_by for proper attribution)
-- 3. External Places (saved a TikTok for this place)
-- 4. Reviews (reviewed the place)
--
-- This enables real-time lookup of place savers without relying on pre-loaded data.
-- Used by PlaceDetailView to show "Saved by" indicator.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_place_savers(
    p_place_id TEXT,
    p_requesting_user_id TEXT DEFAULT NULL
)
RETURNS TABLE(
    user_id TEXT,
    full_name TEXT,
    profile_photo_url TEXT
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
    ),
    -- Filter to only users the requesting user follows (+ self), if provided
    visible_savers AS (
        SELECT DISTINCT s.user_id
        FROM all_savers s
        WHERE 
            -- If no requesting user, return all savers
            p_requesting_user_id IS NULL
            -- Include the requesting user themselves
            OR s.user_id = p_requesting_user_id
            -- Include users the requesting user follows
            OR EXISTS (
                SELECT 1 FROM following f 
                WHERE f.follower_id = p_requesting_user_id 
                AND f.following_id = s.user_id
            )
    )
    SELECT 
        u.id AS user_id,
        u.full_name,
        u.profile_photo_url
    FROM visible_savers vs
    INNER JOIN users u ON vs.user_id = u.id
    ORDER BY 
        -- Put requesting user first if present
        CASE WHEN u.id = p_requesting_user_id THEN 0 ELSE 1 END,
        u.full_name;
END;
$function$;

-- Add comment for documentation
COMMENT ON FUNCTION public.get_place_savers(TEXT, TEXT) IS 
'Returns users who saved a place via favorites, lists, TikToks, or reviews. 
For place lists, uses added_by column to properly attribute who added each place.
Optionally filters to only show users the requesting user follows (+ self).';
