-- ============================================================================
-- Function: is_place_in_user_lists
-- ============================================================================
-- Checks if a specific place is saved in ANY of the user's place lists.
-- Returns true if the place exists in at least one list owned by the user.
--
-- This is used to determine if the bookmark icon should be filled in the
-- place detail view.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.is_place_in_user_lists(p_user_id TEXT, p_place_id TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $function$
BEGIN
    RETURN EXISTS (
        SELECT 1 
        FROM place_list_items pli
        INNER JOIN place_lists pl ON pl.id = pli.list_id
        WHERE pl.user_id = p_user_id 
        AND pli.place_id = p_place_id
    );
END;
$function$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.is_place_in_user_lists(TEXT, TEXT) TO authenticated;
