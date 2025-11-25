-- ============================================================================
-- Function: get_latest_review_photo
-- ============================================================================
-- Two overloads:
-- 1. Returns the latest review photo URL for a single place
-- 2. Returns latest review photo URLs for multiple places (array input)
-- 
-- Note: TikTok thumbnails are no longer fetched from database - they are
-- fetched on-demand in Swift via oEmbed endpoint
-- ============================================================================

-- Overload 1: Single place_id
CREATE OR REPLACE FUNCTION public.get_latest_review_photo(p_place_id text)
RETURNS text
LANGUAGE plpgsql
AS $function$
DECLARE
  result text;
BEGIN
  -- Try to get the most recent review photo from reviews table first
  SELECT unnest(images)
  INTO result
  FROM reviews
  WHERE place_id = p_place_id
    AND images IS NOT NULL
    AND array_length(images, 1) > 0
  ORDER BY timestamp DESC
  LIMIT 1;

  -- If no review photo found, try external_reviews
  IF result IS NULL THEN
    SELECT (media_item->>'imageUrl')::text
    INTO result
    FROM external_reviews er
    CROSS JOIN LATERAL jsonb_array_elements(er.media) AS media_item
    WHERE er.place_id = p_place_id
      AND er.media IS NOT NULL
      AND jsonb_array_length(er.media) > 0
      AND (media_item->>'type')::text ILIKE 'image'
      AND (media_item->>'imageUrl')::text IS NOT NULL
      AND (media_item->>'imageUrl')::text != ''
    ORDER BY er.review_iso_date DESC
    LIMIT 1;
  END IF;

  -- ✅ Removed tiktok_videos fallback - TikTok thumbnails fetched on-demand in Swift
  -- If no photo found, return NULL (Swift will fetch TikTok thumbnail via oEmbed if needed)

  RETURN result;
END;
$function$;

-- Overload 2: Array of place_ids
CREATE OR REPLACE FUNCTION public.get_latest_review_photo(p_place_ids text[])
RETURNS TABLE(place_id text, image_url text)
LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN QUERY
  WITH review_photos AS (
    -- Get the latest review photo for each place_id from reviews table
    SELECT 
      r.place_id, 
      image_elem AS image_url, 
      r.timestamp AS photo_timestamp
    FROM reviews r
    CROSS JOIN LATERAL unnest(r.images) AS image_elem
    WHERE r.place_id = ANY(p_place_ids)
      AND r.images IS NOT NULL
      AND array_length(r.images, 1) > 0
    ORDER BY r.timestamp DESC
  ),
  external_review_photos AS (
    -- Get images from external_reviews.media JSONB array
    SELECT 
      er.place_id,
      (media_item->>'imageUrl')::text AS image_url,
      er.review_iso_date AS photo_timestamp
    FROM external_reviews er
    CROSS JOIN LATERAL jsonb_array_elements(er.media) AS media_item
    WHERE er.place_id = ANY(p_place_ids)
      AND er.media IS NOT NULL
      AND jsonb_array_length(er.media) > 0
      AND (media_item->>'type')::text ILIKE 'image'
      AND (media_item->>'imageUrl')::text IS NOT NULL
      AND (media_item->>'imageUrl')::text != ''
    ORDER BY er.review_iso_date DESC
  ),
  all_photos AS (
    -- Combine both sources, preferring review photos (they come first in UNION)
    SELECT rp.place_id, rp.image_url, rp.photo_timestamp FROM review_photos rp
    UNION ALL
    SELECT erp.place_id, erp.image_url, erp.photo_timestamp FROM external_review_photos erp
  ),
  latest_photo AS (
    -- Select the most recent image per place_id (preferring review photos when timestamps are equal)
    SELECT DISTINCT ON (ap.place_id) ap.place_id, ap.image_url
    FROM all_photos ap
    ORDER BY ap.place_id, ap.photo_timestamp DESC
  )
  -- Return results for all input place_ids, including NULL for those with no images
  SELECT p.place_id, lp.image_url
  FROM unnest(p_place_ids) AS p(place_id)
  LEFT JOIN latest_photo lp ON p.place_id = lp.place_id;
END;
$function$;
