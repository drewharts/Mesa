-- ============================================================================
-- Function: get_my_places_annotations
-- ============================================================================
-- This file contains the current state of the function in the database.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_my_places_annotations(p_user_ids text[], p_bbox geometry)
 RETURNS SETOF place_annotation_with_users
 LANGUAGE sql
 SECURITY DEFINER
AS $function$
SELECT 
    mp.place_id AS id,
    mp.name,
    mp.coordinate,
    array_agg(mp.user_id ORDER BY mp.user_id) AS user_ids
FROM my_places mp
WHERE mp.user_id = ANY(p_user_ids)
AND ST_Intersects(mp.coordinate, p_bbox)
GROUP BY mp.place_id, mp.name, mp.coordinate;
$function$
