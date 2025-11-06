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
    ep.id                                      AS id,          -- unique TikTok import row
    p.name                                     AS name,        -- canonical place name
    p.location                                 AS coordinate,  -- <-- column is `location`
    array_agg(DISTINCT ep.user_id ORDER BY ep.user_id) AS user_ids
FROM external_places ep
JOIN places p ON p.id = ep.place_id
WHERE ep.user_id = ANY(p_user_ids)
  AND ST_Intersects(p.location, p_bbox)                     -- use `location`
GROUP BY ep.id, p.name, p.location;
$function$
