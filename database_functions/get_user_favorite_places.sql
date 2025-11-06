-- ============================================================================
-- Function: get_user_favorite_places
-- ============================================================================
-- This file contains the current state of the function in the database.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_user_favorite_places(p_user_id text)
 RETURNS TABLE(place_id text, name text, coordinate geometry, latest_review_photo text)
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN QUERY
  SELECT 
    f.place_id,
    COALESCE(p.name, f.name) AS name,  -- Use places.name if available, fallback to favorites.name
    COALESCE(f.coordinate, p.location) AS coordinate,  -- Use favorites.coordinate or places.location
    get_latest_review_photo(f.place_id) AS latest_review_photo
  FROM favorites f
  LEFT JOIN places p ON f.place_id = p.id  -- JOIN with places table for current data
  WHERE f.user_id = p_user_id
  ORDER BY f.timestamp DESC;
END;
$function$
