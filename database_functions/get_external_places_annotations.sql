-- ============================================================================
-- Function: get_external_places_annotations
-- ============================================================================
-- This file contains the current state of the function in the database.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_external_places_annotations(p_user_ids text[], p_bbox geometry)
 RETURNS SETOF place_annotation_with_users
 LANGUAGE sql
 STABLE SECURITY DEFINER
AS $function$
SELECT
    p.id                                       AS id,          -- canonical place id
    p.name                                     AS name,
    p.location                                 AS coordinate,
    array_agg(DISTINCT ep.user_id ORDER BY ep.user_id) AS user_ids
FROM external_places ep
JOIN places p ON p.id = ep.place_id
WHERE ep.user_id = ANY(p_user_ids)
  AND ST_Intersects(p.location, p_bbox)
GROUP BY p.id, p.name, p.location;
$function$
