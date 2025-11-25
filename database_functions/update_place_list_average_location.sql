-- ============================================================================
-- Function: update_place_list_average_location
-- ============================================================================
-- This file contains the current state of the function in the database.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.update_place_list_average_location(p_list_id text)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    avg_location geometry;
BEGIN
    -- Calculate the new average location
    avg_location := calculate_place_list_average_location(p_list_id);
    
    -- Update the place_lists table
    UPDATE place_lists 
    SET average_location = avg_location,
        updated_at = NOW()
    WHERE id = p_list_id;
    
    -- Log the update
    RAISE NOTICE 'Updated average_location for list %: %', p_list_id, avg_location;
END;
$function$
