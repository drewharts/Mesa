-- ============================================================================
-- Function: get_favorites_annotations
-- ============================================================================
-- Returns map annotations for user's favorite places
-- Updated: Now includes place_type derived from categories
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_favorites_annotations(p_user_ids text[], p_bbox geometry)
RETURNS TABLE(id text, name text, coordinate geometry, user_ids text[], place_type text)
LANGUAGE sql
SECURITY DEFINER
AS $function$
SELECT 
    f.place_id AS id,
    COALESCE(p.name, f.name) AS name,
    COALESCE(f.coordinate, p.location) AS coordinate,
    array_agg(f.user_id ORDER BY f.user_id) AS user_ids,
    COALESCE(
        p.user_corrected_category,
        (SELECT cat FROM unnest(p.categories) AS cat
         WHERE LOWER(cat) NOT IN ('establishment', 'point_of_interest', 'food', 'store', 'place', 'health')
         LIMIT 1),
        p.categories[1],
        'Place'
    ) AS place_type
FROM favorites f
LEFT JOIN places p ON f.place_id = p.id
WHERE f.user_id = ANY(p_user_ids)
AND ST_Intersects(COALESCE(f.coordinate, p.location), p_bbox)
GROUP BY f.place_id, COALESCE(p.name, f.name), COALESCE(f.coordinate, p.location), p.categories, p.user_corrected_category;
$function$;
