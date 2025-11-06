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
  -- Try to get the most recent review photo
  SELECT unnest(images)
  INTO result
  FROM reviews
  WHERE place_id = p_place_id
    AND images IS NOT NULL
    AND array_length(images, 1) > 0
  ORDER BY timestamp DESC
  LIMIT 1;

  -- ✅ Removed tiktok_videos fallback - TikTok thumbnails fetched on-demand in Swift
  -- If no review photo found, return NULL (Swift will fetch TikTok thumbnail via oEmbed if needed)

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
    -- Get the latest review photo for each place_id
    SELECT r.place_id, unnest(r.images) AS image_url
    FROM reviews r
    WHERE r.place_id = ANY(p_place_ids)
      AND r.images IS NOT NULL
      AND array_length(r.images, 1) > 0
    ORDER BY r.timestamp DESC
  ),
  latest_review_photo AS (
    -- Select the most recent image per place_id
    SELECT DISTINCT ON (review_photos.place_id) review_photos.place_id, review_photos.image_url
    FROM review_photos
  )
  -- ✅ Removed tiktok_thumbnails CTE - TikTok thumbnails fetched on-demand in Swift
  -- Return results for all input place_ids, including NULL for those with no review images
  SELECT p.place_id, lrp.image_url
  FROM unnest(p_place_ids) AS p(place_id)
  LEFT JOIN latest_review_photo lrp ON p.place_id = lrp.place_id;
END;
$function$;
