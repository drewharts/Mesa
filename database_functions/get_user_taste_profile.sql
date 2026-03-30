-- ============================================================================
-- Function: get_user_taste_profile
-- ============================================================================
-- Returns a user's place type distribution across all their saved places
-- (reviews, favorites, my_places, list items). Used for taste profile graphic.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_user_taste_profile(
    p_user_id text
)
RETURNS TABLE(
    place_type text,
    count bigint
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $function$
WITH user_places AS (
    SELECT DISTINCT place_id FROM reviews WHERE user_id = p_user_id
    UNION
    SELECT DISTINCT place_id FROM favorites WHERE user_id = p_user_id
    UNION
    SELECT DISTINCT place_id FROM my_places WHERE user_id = p_user_id
    UNION
    SELECT DISTINCT pli.place_id
    FROM place_list_items pli
    JOIN place_lists pl ON pli.list_id = pl.id
    WHERE pl.user_id = p_user_id
)
SELECT
    COALESCE(
        p.user_corrected_category,
        (SELECT cat FROM unnest(p.categories) AS cat
         WHERE LOWER(cat) NOT IN ('establishment', 'point_of_interest', 'food', 'store', 'place', 'health')
         LIMIT 1),
        p.categories[1],
        'Place'
    ) AS place_type,
    COUNT(*) AS count
FROM user_places up
JOIN places p ON up.place_id = p.id
GROUP BY place_type
ORDER BY count DESC
LIMIT 8;
$function$;
