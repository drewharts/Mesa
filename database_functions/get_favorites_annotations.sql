-- ============================================================================
-- Function: get_favorites_annotations
-- ============================================================================
-- This file contains the current state of the function in the database.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_favorites_annotations(p_user_ids text[], p_bbox geometry)
 RETURNS SETOF place_annotation_with_users
 LANGUAGE sql
 SECURITY DEFINER
AS $function$
SELECT 
    f.place_id AS id,
    COALESCE(p.name, f.name) AS name,  -- Use places.name if available
    COALESCE(f.coordinate, p.location) AS coordinate,  -- Use favorites.coordinate or places.location
    array_agg(f.user_id ORDER BY f.user_id) AS user_ids
FROM favorites f
LEFT JOIN places p ON f.place_id = p.id  -- JOIN for current place data
WHERE f.user_id = ANY(p_user_ids)
AND ST_Intersects(COALESCE(f.coordinate, p.location), p_bbox)
GROUP BY f.place_id, COALESCE(p.name, f.name), COALESCE(f.coordinate, p.location);
$function$
