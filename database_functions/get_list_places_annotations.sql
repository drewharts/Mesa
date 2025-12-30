-- ============================================================================
-- Function: get_list_places_annotations
-- ============================================================================
-- Returns place annotations for map display from place lists
-- Uses added_by to attribute places to the user who added them (not list owner)
-- Falls back to list owner for backward compatibility with existing data
-- Updated: Now includes place_type derived from categories
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_list_places_annotations(p_user_ids text[], p_bbox geometry)
RETURNS TABLE(id text, name text, coordinate geometry, user_ids text[], place_type text)
LANGUAGE sql
SECURITY DEFINER
AS $function$
SELECT 
    pli.place_id AS id,
    p.name,
    p.location AS coordinate,
    array_agg(COALESCE(pli.added_by, pl.user_id) ORDER BY COALESCE(pli.added_by, pl.user_id)) AS user_ids,
    COALESCE(
        (SELECT cat FROM unnest(p.categories) AS cat
         WHERE LOWER(cat) NOT IN ('establishment', 'point_of_interest', 'food', 'store', 'place', 'health')
         LIMIT 1),
        p.categories[1],
        'Place'
    ) AS place_type
FROM place_list_items pli
INNER JOIN place_lists pl ON pli.list_id = pl.id
INNER JOIN places p ON pli.place_id = p.id
WHERE COALESCE(pli.added_by, pl.user_id) = ANY(p_user_ids)
AND ST_Intersects(p.location, p_bbox)
GROUP BY pli.place_id, p.name, p.location, p.categories;
$function$;
