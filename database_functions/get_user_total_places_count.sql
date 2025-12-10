-- ============================================================================
-- Function: get_user_total_places_count
-- ============================================================================
-- Returns the total count of UNIQUE places a user has interacted with.
-- This includes places that have been:
--   - Saved to any list (place_list_items)
--   - Added as favorites
--   - Reviewed
--   - Created/imported (my_places)
--
-- The function deduplicates across all sources to give an accurate count.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_user_total_places_count(p_user_id TEXT)
RETURNS TABLE(
    total_places_count BIGINT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $function$
BEGIN
    RETURN QUERY
    SELECT COUNT(DISTINCT place_id)::BIGINT AS total_places_count
    FROM (
        -- Places in user's lists
        SELECT pli.place_id
        FROM place_list_items pli
        INNER JOIN place_lists pl ON pl.id = pli.list_id
        WHERE pl.user_id = p_user_id
        
        UNION
        
        -- User's favorites
        SELECT f.place_id
        FROM favorites f
        WHERE f.user_id = p_user_id
        
        UNION
        
        -- Places user has reviewed
        SELECT r.place_id
        FROM reviews r
        WHERE r.user_id = p_user_id
        
        UNION
        
        -- Places user created/imported (my_places)
        SELECT mp.place_id
        FROM my_places mp
        WHERE mp.user_id = p_user_id
    ) AS all_places;
END;
$function$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_user_total_places_count(TEXT) TO authenticated;

