-- ============================================================================
-- Function: get_trending_places
-- ============================================================================
-- Returns places ranked by crown (like) count for the trending section.
-- Includes place photo for visual display.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_trending_places(
    p_limit int DEFAULT 10
)
RETURNS TABLE(
    place_id text,
    place_name text,
    city text,
    place_type text,
    crown_count bigint,
    photo_url text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $function$
SELECT
    r.place_id::text AS place_id,
    p.name AS place_name,
    normalize_city_name(p.city) AS city,
    COALESCE(
        p.user_corrected_category,
        (SELECT cat FROM unnest(p.categories) AS cat
         WHERE LOWER(cat) NOT IN ('establishment', 'point_of_interest', 'food', 'store', 'place', 'health')
         LIMIT 1),
        p.categories[1],
        'Place'
    ) AS place_type,
    COUNT(*) AS crown_count,
    p.photo_urls[1] AS photo_url
FROM review_likes rl
JOIN reviews r ON rl.review_id = r.id
JOIN places p ON r.place_id::text = p.id::text
WHERE p.name IS NOT NULL
GROUP BY r.place_id, p.name, p.city, p.categories, p.user_corrected_category, p.photo_urls
ORDER BY crown_count DESC, p.name
LIMIT p_limit;
$function$;
