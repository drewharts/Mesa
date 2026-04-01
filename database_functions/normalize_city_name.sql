-- ============================================================================
-- Function: normalize_city_name
-- ============================================================================
-- Maps borough/suburb names to their metro area name.
-- Used by explore RPCs to group and filter by metro area.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.normalize_city_name(raw_city text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $function$
SELECT CASE
    -- New York City metro
    WHEN raw_city IN ('Kings County', 'Brooklyn', 'Queens County', 'Queens',
                      'Bronx County', 'The Bronx', 'Bronx',
                      'Richmond County', 'Staten Island',
                      'New York County', 'Manhattan', 'New York') THEN 'New York City'
    -- Los Angeles metro
    WHEN raw_city IN ('Beverly Hills', 'Santa Monica', 'West Hollywood',
                      'Culver City', 'Pasadena', 'Burbank', 'Glendale',
                      'Long Beach', 'Inglewood') THEN 'Los Angeles'
    -- London
    WHEN raw_city IN ('Greater London', 'City of London', 'City of Westminster') THEN 'London'
    -- Otherwise keep as-is
    ELSE raw_city
END;
$function$;
