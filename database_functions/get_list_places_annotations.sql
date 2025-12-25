-- ============================================================================
-- Function: get_list_places_annotations
-- ============================================================================
-- Returns place annotations for map display from place lists
-- Uses added_by to attribute places to the user who added them (not list owner)
-- Falls back to list owner for backward compatibility with existing data
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_list_places_annotations(p_user_ids text[], p_bbox geometry)
RETURNS SETOF place_annotation_with_users
LANGUAGE sql
SECURITY DEFINER
AS $function$
SELECT 
    pli.place_id AS id,
    p.name,
    p.location,
    -- Use added_by (the person who added the place), falling back to list owner
    array_agg(COALESCE(pli.added_by, pl.user_id) ORDER BY COALESCE(pli.added_by, pl.user_id)) AS user_ids
FROM place_list_items pli
INNER JOIN place_lists pl ON pli.list_id = pl.id
INNER JOIN places p ON pli.place_id = p.id
WHERE COALESCE(pli.added_by, pl.user_id) = ANY(p_user_ids)
AND ST_Intersects(p.location, p_bbox)
GROUP BY pli.place_id, p.name, p.location;
$function$;
