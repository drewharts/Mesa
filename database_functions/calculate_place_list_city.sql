-- ============================================================================
-- Function: calculate_place_list_city
-- ============================================================================
-- Computes the most common city among a list's places.
-- Returns NULL if no places have city data.
-- Tiebreaks alphabetically for determinism.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.calculate_place_list_city(p_list_id text)
RETURNS text
LANGUAGE plpgsql
AS $function$
DECLARE
    result_city text;
BEGIN
    SELECT p.city INTO result_city
    FROM place_list_items pli
    JOIN places p ON p.id = pli.place_id
    WHERE pli.list_id = p_list_id
      AND p.city IS NOT NULL
      AND p.city != ''
    GROUP BY p.city
    ORDER BY COUNT(*) DESC, p.city ASC
    LIMIT 1;

    RETURN result_city;
END;
$function$;
