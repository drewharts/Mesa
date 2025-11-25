-- ===================================================================
-- FAVORITES TABLE FIX - JOIN WITH PLACES FOR NORMALIZED DATA
-- ===================================================================
-- 
-- Problem: Favorites table was storing denormalized place data (name, address, etc.)
-- Solution: Store only IDs in favorites, JOIN with places table when querying
--
-- Changes made:
-- 1. Updated get_user_favorite_places to JOIN with places table
-- 2. Updated get_favorites_annotations to JOIN with places table
-- 3. Modified addFavorite in Swift to only insert IDs + timestamp
--
-- ===================================================================

-- 1. Update get_user_favorite_places to JOIN with places table
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
$function$;

-- 2. Update get_favorites_annotations to JOIN with places table
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
$function$;

-- ===================================================================
-- BENEFITS OF THIS APPROACH:
-- ===================================================================
-- 1. No data duplication - place data only in places table
-- 2. Always shows current place data (name, address automatically updated)
-- 3. Smaller favorites table (only stores relationships)
-- 4. Simpler Swift code (fewer parameters to pass)
--
-- The COALESCE handles backward compatibility with existing favorites
-- that have denormalized data in the name/coordinate columns.
-- ===================================================================

