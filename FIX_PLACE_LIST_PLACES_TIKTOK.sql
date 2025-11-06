-- ============================================================================
-- FIX PLACE LIST PLACES - Remove tiktok_videos column reference
-- ============================================================================
-- This fixes the error: column "tiktok_videos" does not exist
-- The external_places table no longer has tiktok_videos column,
-- only the url column. TikTok metadata is now fetched on-demand via oEmbed.
--
-- Date: 2025-01-29
-- ============================================================================

-- ============================================================================
-- 1. Update get_latest_review_photo (single place_id)
-- ============================================================================
-- Remove tiktok_videos fallback since we can't get thumbnail from DB anymore
-- TikTok thumbnails will be fetched on-demand in Swift via oEmbed endpoint
CREATE OR REPLACE FUNCTION get_latest_review_photo(p_place_id text)
RETURNS text
LANGUAGE plpgsql
AS $$
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
$$;

-- ============================================================================
-- 2. Update get_latest_review_photo (array of place_ids)
-- ============================================================================
-- Remove tiktok_videos fallback for array version as well
CREATE OR REPLACE FUNCTION get_latest_review_photo(p_place_ids text[])
RETURNS TABLE(place_id text, image_url text)
LANGUAGE plpgsql
AS $$
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
$$;

-- ============================================================================
-- 3. Update get_paginated_place_list_places to include external_place_id
-- ============================================================================
-- Add external_place_id to the return so Swift can fetch TikTok thumbnails on-demand
CREATE OR REPLACE FUNCTION get_paginated_place_list_places(
    p_list_id text, 
    p_page integer, 
    p_page_size integer
)
RETURNS TABLE(
    place_id text, 
    name text, 
    coordinate geometry, 
    latest_review_photo text,
    external_place_id text  -- ✅ Added: UUID from external_places table
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    pli.place_id,
    p.name,
    p.location AS coordinate,
    get_latest_review_photo(pli.place_id) AS latest_review_photo,
    ep.id::text AS external_place_id  -- ✅ Added: Join with external_places to get ID
  FROM place_list_items pli
  JOIN places p ON pli.place_id = p.id
  LEFT JOIN external_places ep ON ep.place_id = pli.place_id  -- ✅ Added: LEFT JOIN to get external_place_id if exists
  WHERE pli.list_id = p_list_id
  ORDER BY pli.sort_order ASC NULLS LAST, pli.place_id
  OFFSET (p_page - 1) * p_page_size
  LIMIT p_page_size;
END;
$$;

-- ============================================================================
-- TESTING
-- ============================================================================
-- Test with a list ID:
-- SELECT * FROM get_paginated_place_list_places('your-list-id', 1, 6);
--
-- Expected result:
-- - Returns place_id, name, coordinate, latest_review_photo, external_place_id
-- - latest_review_photo will be NULL if no review photos exist (TikTok thumbnails fetched in Swift)
-- - external_place_id will be NULL if place doesn't have a TikTok video
-- ============================================================================

