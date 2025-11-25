-- ============================================================================
-- Function: get_reviewed_places_annotations
-- ============================================================================
-- This file contains the current state of the function in the database.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_reviewed_places_annotations(p_user_ids text[], p_bbox geometry)
 RETURNS TABLE(id text, name text, coordinate geometry, user_ids text[])
 LANGUAGE sql
 STABLE
AS $function$
SELECT 
    r.place_id AS id,
    p.name,
    p.location AS coordinate,
    array_agg(DISTINCT r.user_id ORDER BY r.user_id) AS user_ids
FROM reviews r
INNER JOIN places p ON r.place_id = p.id
WHERE r.user_id = ANY(p_user_ids)
AND ST_Intersects(p.location, p_bbox)
GROUP BY r.place_id, p.name, p.location
$function$
