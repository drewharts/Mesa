-- Batched replacement for calling get_paginated_place_list_places once per list.
-- Returns the first p_page_size places of every requested list in one round trip,
-- with the same columns (plus list_id) and the same ordering as the per-list RPC.
-- Applied as migration: add_get_first_places_for_lists
CREATE OR REPLACE FUNCTION public.get_first_places_for_lists(
  p_list_ids text[],
  p_page_size integer DEFAULT 6
)
RETURNS TABLE(
  list_id text,
  place_id text,
  name text,
  latitude double precision,
  longitude double precision,
  latest_review_photo text,
  external_place_id text,
  tiktok_url text,
  place_type text,
  added_by_user_id text,
  added_by_name text,
  added_by_photo_url text,
  thumbnail_url text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $function$
  SELECT
    pl.id AS list_id,
    item.place_id,
    p.name,
    ST_Y(p.location::geometry)::double precision AS latitude,
    ST_X(p.location::geometry)::double precision AS longitude,
    get_latest_review_photo(item.place_id) AS latest_review_photo,
    ep.id::text AS external_place_id,
    ep.url AS tiktok_url,
    COALESCE(
      (SELECT cat FROM unnest(p.categories) AS cat
       WHERE LOWER(cat) NOT IN ('establishment', 'point_of_interest', 'food', 'store', 'place', 'health')
       LIMIT 1),
      p.categories[1]
    ) AS place_type,
    item.added_by AS added_by_user_id,
    u.full_name AS added_by_name,
    u.profile_photo_url AS added_by_photo_url,
    p.thumbnail_url
  FROM place_lists pl
  CROSS JOIN LATERAL (
    SELECT pli.place_id, pli.added_by, pli.sort_order
    FROM place_list_items pli
    JOIN places pp ON pp.id = pli.place_id
    WHERE pli.list_id = pl.id
    ORDER BY pli.sort_order ASC NULLS LAST, pli.place_id
    LIMIT p_page_size
  ) item
  JOIN places p ON p.id = item.place_id
  LEFT JOIN LATERAL (
    SELECT e.id, e.url
    FROM external_places e
    WHERE e.place_id = item.place_id
      AND e.user_id = pl.user_id
    ORDER BY e.id
    LIMIT 1
  ) ep ON true
  LEFT JOIN users u ON item.added_by = u.id
  WHERE pl.id = ANY(p_list_ids)
  ORDER BY pl.id, item.sort_order ASC NULLS LAST, item.place_id;
$function$;

GRANT EXECUTE ON FUNCTION public.get_first_places_for_lists(text[], integer) TO anon, authenticated;
