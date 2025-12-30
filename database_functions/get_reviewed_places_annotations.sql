-- ============================================================================
-- Function: get_reviewed_places_annotations
-- ============================================================================
-- Returns map annotations for places user has reviewed
-- Updated: Now includes place_type derived from categories
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_reviewed_places_annotations(p_user_ids text[], p_bbox geometry)
RETURNS TABLE(id text, name text, coordinate geometry, user_ids text[], place_type text)
LANGUAGE sql
STABLE
AS $function$
SELECT 
    r.place_id AS id,
    p.name,
    p.location AS coordinate,
    array_agg(DISTINCT r.user_id ORDER BY r.user_id) AS user_ids,
    COALESCE(
        (SELECT cat FROM unnest(p.categories) AS cat
         WHERE LOWER(cat) NOT IN ('establishment', 'point_of_interest', 'food', 'store', 'place', 'health')
         LIMIT 1),
        p.categories[1],
        'Place'
    ) AS place_type
FROM reviews r
INNER JOIN places p ON r.place_id = p.id
WHERE r.user_id = ANY(p_user_ids)
AND ST_Intersects(p.location, p_bbox)
GROUP BY r.place_id, p.name, p.location, p.categories;
$function$;
