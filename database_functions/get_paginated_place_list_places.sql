-- ============================================================================
-- Function: get_paginated_place_list_places
-- ============================================================================
-- Returns paginated list of places in a place list with their details
-- Includes latest review photo and external_place_id for TikTok places
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_paginated_place_list_places(
    p_list_id text, 
    p_page integer, 
    p_page_size integer
)
RETURNS TABLE(
    place_id text, 
    name text, 
    coordinate geometry, 
    latest_review_photo text,
    external_place_id text
)
LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN QUERY
  SELECT 
    pli.place_id,
    p.name,
    p.location AS coordinate,
    get_latest_review_photo(pli.place_id) AS latest_review_photo,
    ep.id::text AS external_place_id
  FROM place_list_items pli
  JOIN places p ON pli.place_id = p.id
  LEFT JOIN external_places ep ON ep.place_id = pli.place_id
  WHERE pli.list_id = p_list_id
  ORDER BY pli.sort_order ASC NULLS LAST, pli.place_id
  OFFSET (p_page - 1) * p_page_size
  LIMIT p_page_size;
END;
$function$;
