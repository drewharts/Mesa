-- ============================================================================
-- Function: calculate_place_list_average_location
-- ============================================================================
-- This file contains the current state of the function in the database.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.calculate_place_list_average_location(p_list_id text)
 RETURNS geometry
 LANGUAGE plpgsql
AS $function$
DECLARE
    avg_location geometry;
BEGIN
    -- Calculate the centroid of all places in the list
    SELECT ST_Centroid(ST_Collect(p.location))
    INTO avg_location
    FROM place_lists pl
    JOIN place_list_items pli ON pl.id = pli.list_id
    JOIN places p ON pli.place_id = p.id
    WHERE pl.id = p_list_id
    AND p.location IS NOT NULL;
    
    RETURN avg_location;
END;
$function$
