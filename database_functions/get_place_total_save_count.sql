-- ============================================================================
-- Function: get_place_total_save_count
-- ============================================================================
-- Returns the total number of unique users who have saved a place
-- Counts from ALL save sources: favorites, place_list_items, my_places, 
-- external_places (TikTok), and reviews
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_place_total_save_count(p_place_id text)
RETURNS bigint
LANGUAGE sql
STABLE
AS $$
  SELECT COUNT(DISTINCT user_id)
  FROM (
    -- Favorites
    SELECT user_id FROM favorites WHERE place_id = p_place_id
    UNION ALL
    -- Place list items (use added_by if available, fall back to list owner)
    SELECT COALESCE(pli.added_by, pl.user_id) as user_id
    FROM place_list_items pli
    JOIN place_lists pl ON pli.list_id = pl.id 
    WHERE pli.place_id = p_place_id
    UNION ALL
    -- My places (user-created places)
    SELECT user_id FROM my_places WHERE place_id = p_place_id
    UNION ALL
    -- External places (TikTok, etc.)
    SELECT user_id FROM external_places WHERE place_id = p_place_id
    UNION ALL
    -- Reviews (reviewed places count as saves)
    SELECT user_id FROM reviews WHERE place_id = p_place_id
  ) AS all_saves;
$$;

