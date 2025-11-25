-- ============================================================================
-- Function: get_user_stats
-- ============================================================================
-- Returns user statistics including counts for favorites, lists, reviews,
-- followers, following, and my_places
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_user_stats(p_user_id uuid)
RETURNS TABLE(
    favorites_count bigint, 
    lists_count bigint, 
    reviews_count bigint, 
    followers_count bigint, 
    following_count bigint, 
    my_places_count bigint
)
LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        (SELECT COUNT(*) FROM favorites WHERE user_id = p_user_id) AS favorites_count,
        (SELECT COUNT(*) FROM place_lists WHERE user_id = p_user_id) AS lists_count,
        (SELECT COUNT(*) FROM reviews WHERE user_id = p_user_id) AS reviews_count,
        (SELECT COUNT(*) FROM following WHERE following_id = p_user_id) AS followers_count,
        (SELECT COUNT(*) FROM following WHERE follower_id = p_user_id) AS following_count,
        (SELECT COUNT(*) FROM my_places WHERE user_id = p_user_id) AS my_places_count;
END;
$function$;
