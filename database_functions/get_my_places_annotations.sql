-- ============================================================================
-- Function: get_my_places_annotations
-- ============================================================================
-- Returns map annotations for user's created places (my_places)
-- Updated: Now includes place_type derived from categories
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_my_places_annotations(p_user_ids text[], p_bbox geometry)
RETURNS TABLE(id text, name text, coordinate geometry, user_ids text[], place_type text)
LANGUAGE sql
SECURITY DEFINER
AS $function$
SELECT 
    mp.place_id AS id,
    p.name,
    mp.coordinate,
    array_agg(mp.user_id ORDER BY mp.user_id) AS user_ids,
    COALESCE(
        (SELECT cat FROM unnest(p.categories) AS cat
         WHERE LOWER(cat) NOT IN ('establishment', 'point_of_interest', 'food', 'store', 'place', 'health')
         LIMIT 1),
        p.categories[1],
        'Place'
    ) AS place_type
FROM my_places mp
JOIN places p ON p.id::text = mp.place_id
WHERE mp.user_id = ANY(p_user_ids)
AND ST_Intersects(mp.coordinate, p_bbox)
GROUP BY mp.place_id, p.name, mp.coordinate, p.categories;
$function$;
