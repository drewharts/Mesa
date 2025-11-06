-- ============================================================================
-- Update get_paginated_place_list_places to include tiktok_url
-- ============================================================================
-- This allows place list tiles to display TikTok thumbnails for places where
-- the list owner has saved TikTok videos
-- ============================================================================

DROP FUNCTION IF EXISTS get_paginated_place_list_places(text, integer, integer);

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
    tiktok_url text
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
    ep.url AS tiktok_url
  FROM place_list_items pli
  JOIN places p ON pli.place_id = p.id
  JOIN place_lists pl ON pli.list_id = pl.id
  LEFT JOIN external_places ep ON ep.place_id = pli.place_id 
    AND ep.user_id = pl.user_id
  WHERE pli.list_id = p_list_id
  ORDER BY pli.sort_order ASC NULLS LAST, pli.place_id
  OFFSET (p_page - 1) * p_page_size
  LIMIT p_page_size;
END;
$function$;

