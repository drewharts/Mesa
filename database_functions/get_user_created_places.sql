-- ============================================================================
-- Function: get_user_created_places
-- ============================================================================
-- This file contains the current state of the function in the database.
-- NOTE: This function has 2 overloaded versions.
-- ============================================================================

-- Overload 1 of 2
CREATE OR REPLACE FUNCTION public.get_user_created_places(p_user_id text)
 RETURNS TABLE(place_id text, name text, coordinate geometry, latest_review_photo text)
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN QUERY
  SELECT 
    mp.place_id,
    mp.name,
    mp.coordinate,
    get_latest_review_photo(mp.place_id) AS latest_review_photo
  FROM my_places mp
  WHERE mp.user_id = p_user_id
  ORDER BY mp.place_id;
END;
$function$


-- Overload 2 of 2
CREATE OR REPLACE FUNCTION public.get_user_created_places(p_user_id text, p_limit integer, p_offset integer)
 RETURNS TABLE(place_id text, name text, coordinate geometry, latest_review_photo text)
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN QUERY
  SELECT 
    mp.place_id,
    mp.name,
    mp.coordinate,
    get_latest_review_photo(mp.place_id) AS latest_review_photo
  FROM my_places mp
  WHERE mp.user_id = p_user_id
  ORDER BY mp.place_id
  LIMIT p_limit
  OFFSET p_offset;
END;
$function$
