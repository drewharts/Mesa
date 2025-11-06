-- ============================================================================
-- Function: get_bounding_box
-- ============================================================================
-- Helper function to create a bounding box geometry from min/max coordinates
-- Used for viewport-based queries
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_bounding_box(
    p_min_lon double precision, 
    p_min_lat double precision, 
    p_max_lon double precision, 
    p_max_lat double precision
)
RETURNS geometry
LANGUAGE sql
AS $function$
SELECT ST_MakeEnvelope(p_min_lon, p_min_lat, p_max_lon, p_max_lat, 4326);
$function$;

