-- ============================================================================
-- Function: get_custom_place_creator
-- ============================================================================
-- Returns the user who created a custom place (via my_places table).
-- Custom places are user-created places that don't come from Google/Mapbox.
--
-- Returns NULL if the place was not created by a user (i.e., not a custom place).
-- Used by PlaceDetailView to show "Created by [User]" for custom places.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_custom_place_creator(p_place_id TEXT)
RETURNS TABLE(
    creator_user_id TEXT,
    creator_full_name TEXT,
    creator_profile_photo_url TEXT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        u.id::TEXT AS creator_user_id,
        u.full_name AS creator_full_name,
        u.profile_photo_url AS creator_profile_photo_url
    FROM my_places mp
    INNER JOIN users u ON mp.user_id = u.id::TEXT
    WHERE mp.place_id = p_place_id
    LIMIT 1;
END;
$function$;

-- Add comment for documentation
COMMENT ON FUNCTION public.get_custom_place_creator(TEXT) IS 
'Returns the user who created a custom place. Returns NULL for non-custom places.
Used to display "Created by [Name]" in the place detail view.';

