-- ============================================================================
-- Function: update_place_list_average_location
-- ============================================================================
-- Triggered on place_list_items INSERT/UPDATE/DELETE.
-- Updates both average_location and city on the parent place_lists row.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.update_place_list_average_location(p_list_id text)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    avg_location geometry;
    computed_city text;
BEGIN
    -- Calculate the new average location
    avg_location := calculate_place_list_average_location(p_list_id);

    -- Calculate the most common city among the list's places
    computed_city := calculate_place_list_city(p_list_id);

    -- Update the place_lists table
    UPDATE place_lists
    SET average_location = avg_location,
        city = computed_city,
        updated_at = NOW()
    WHERE id = p_list_id;

    -- Log the update
    RAISE NOTICE 'Updated average_location and city for list %: %, %', p_list_id, avg_location, computed_city;
END;
$function$;
