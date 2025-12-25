-- ============================================================================
-- Function: get_paginated_place_list_places
-- ============================================================================
-- Returns paginated list of places in a place list with their details
-- Includes latest review photo and TikTok URL for places where list owner has TikTok videos
-- Also includes added_by information for collaborative list attribution
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
    external_place_id text,
    tiktok_url text,
    added_by_user_id text,
    added_by_name text,
    added_by_photo_url text
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
    ep.id::text AS external_place_id,
    ep.url AS tiktok_url,
    pli.added_by AS added_by_user_id,
    u.full_name AS added_by_name,
    u.profile_photo_url AS added_by_photo_url
  FROM place_list_items pli
  JOIN places p ON pli.place_id = p.id
  JOIN place_lists pl ON pli.list_id = pl.id
  LEFT JOIN external_places ep ON ep.place_id = pli.place_id 
    AND ep.user_id = pl.user_id
  LEFT JOIN users u ON pli.added_by = u.id
  WHERE pli.list_id = p_list_id
  ORDER BY pli.sort_order ASC NULLS LAST, pli.place_id
  OFFSET (p_page - 1) * p_page_size
  LIMIT p_page_size;
END;
$function$;
