-- ============================================================================
-- Function: get_user_year_in_review
-- ============================================================================
-- Returns summary stats for a user's activity on Mesa.
-- Used for the shareable year-in-review / recap card.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_user_year_in_review(
    p_user_id text
)
RETURNS TABLE(
    places_reviewed bigint,
    places_favorited bigint,
    lists_created bigint,
    videos_imported bigint,
    crowns_received bigint,
    top_city text,
    cities_count bigint
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $function$
SELECT
    (SELECT COUNT(DISTINCT place_id) FROM reviews WHERE user_id = p_user_id),
    (SELECT COUNT(*) FROM favorites WHERE user_id = p_user_id),
    (SELECT COUNT(*) FROM place_lists WHERE user_id = p_user_id),
    (SELECT COUNT(*) FROM external_places WHERE user_id = p_user_id),
    (SELECT COUNT(*) FROM review_likes rl JOIN reviews r ON rl.review_id = r.id WHERE r.user_id = p_user_id),
    (SELECT normalize_city_name(p.city)
     FROM reviews r JOIN places p ON r.place_id = p.id
     WHERE r.user_id = p_user_id AND p.city IS NOT NULL AND p.city != ''
     GROUP BY normalize_city_name(p.city)
     ORDER BY COUNT(*) DESC LIMIT 1),
    (SELECT COUNT(DISTINCT normalize_city_name(p.city))
     FROM reviews r JOIN places p ON r.place_id = p.id
     WHERE r.user_id = p_user_id AND p.city IS NOT NULL AND p.city != '');
$function$;
