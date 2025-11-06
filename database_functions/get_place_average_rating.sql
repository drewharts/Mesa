-- ============================================================================
-- Function: get_place_average_rating
-- ============================================================================
-- This file contains the current state of the function in the database.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_place_average_rating(p_place_id uuid)
 RETURNS double precision
 LANGUAGE plpgsql
AS $function$
DECLARE
    avg_rating FLOAT;
BEGIN
    SELECT AVG((food_rating + service_rating + ambience_rating) / 3.0)
    INTO avg_rating
    FROM reviews
    WHERE place_id = p_place_id
    AND food_rating IS NOT NULL
    AND service_rating IS NOT NULL
    AND ambience_rating IS NOT NULL;
    
    RETURN COALESCE(avg_rating, 0.0);
END;
$function$
