-- ============================================================================
-- Function: trigger_update_place_list_average_location
-- ============================================================================
-- This file contains the current state of the function in the database.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.trigger_update_place_list_average_location()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    -- Update average_location for the affected list
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        PERFORM update_place_list_average_location(NEW.list_id);
    ELSIF TG_OP = 'DELETE' THEN
        PERFORM update_place_list_average_location(OLD.list_id);
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$function$
