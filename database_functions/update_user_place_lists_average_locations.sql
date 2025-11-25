-- ============================================================================
-- Function: update_user_place_lists_average_locations
-- ============================================================================
-- This file contains the current state of the function in the database.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.update_user_place_lists_average_locations(p_user_id text)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    list_record RECORD;
BEGIN
    -- Update average_location for all lists belonging to the user
    FOR list_record IN 
        SELECT id FROM place_lists WHERE user_id = p_user_id
    LOOP
        PERFORM update_place_list_average_location(list_record.id);
    END LOOP;
    
    RAISE NOTICE 'Updated average_locations for all lists of user %', p_user_id;
END;
$function$
