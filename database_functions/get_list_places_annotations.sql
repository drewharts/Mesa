-- ============================================================================
-- Function: get_list_places_annotations
-- ============================================================================
-- This file contains the current state of the function in the database.
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
    array_agg(pl.user_id ORDER BY pl.user_id) AS user_ids
FROM place_list_items pli
INNER JOIN place_lists pl ON pli.list_id = pl.id
INNER JOIN places p ON pli.place_id = p.id
WHERE pl.user_id = ANY(p_user_ids)
AND ST_Intersects(p.location, p_bbox)
GROUP BY pli.place_id, p.name, p.location;
$function$
