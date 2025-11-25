-- ============================================================================
-- Migration: Remove sort_order column from place_lists table
-- ============================================================================
-- This migration removes the sort_order column from place_lists table.
-- Lists will now be ordered by created_at DESC (newest first) when location
-- is not available, or by proximity when location is available.
-- ============================================================================
-- ✅ MIGRATION APPLIED SUCCESSFULLY via MCP on database
-- ============================================================================

-- Drop the existing function first (needed because return type is changing)
DROP FUNCTION IF EXISTS public.get_user_place_lists_by_proximity(text, double precision, double precision);

-- Recreate the function without sort_order in return type
CREATE OR REPLACE FUNCTION public.get_user_place_lists_by_proximity(p_user_id text, p_user_lat double precision DEFAULT NULL::double precision, p_user_lng double precision DEFAULT NULL::double precision)
 RETURNS TABLE(id text, user_id text, name text, description text, average_location text, is_public boolean, image text, created_at timestamp without time zone, updated_at timestamp without time zone, distance_meters double precision)
 LANGUAGE plpgsql
AS $function$BEGIN
    RETURN QUERY
    SELECT 
        pl.id,
        pl.user_id,
        pl.name,
        pl.description,
        ST_AsText(pl.average_location) AS average_location,
        pl.is_public,
        pl.image,
        pl.created_at,
        pl.updated_at,
        CASE 
            WHEN p_user_lat IS NOT NULL AND p_user_lng IS NOT NULL AND pl.average_location IS NOT NULL THEN
                ST_Distance(
                    pl.average_location::geography,
                    ST_SetSRID(ST_MakePoint(p_user_lng, p_user_lat), 4326)::geography
                )
            ELSE NULL
        END AS distance_meters
    FROM place_lists pl
    WHERE pl.user_id = p_user_id
    ORDER BY 
        CASE 
            WHEN p_user_lat IS NOT NULL AND p_user_lng IS NOT NULL AND pl.average_location IS NOT NULL THEN
                ST_Distance(
                    pl.average_location::geography,
                    ST_SetSRID(ST_MakePoint(p_user_lng, p_user_lat), 4326)::geography
                )
            ELSE NULL
        END ASC NULLS LAST,
        pl.created_at DESC NULLS LAST,
        pl.name ASC;
END;$function$;

-- Drop the index on sort_order
DROP INDEX IF EXISTS idx_place_lists_sort_order;

-- Drop the sort_order column from place_lists table
ALTER TABLE place_lists DROP COLUMN IF EXISTS sort_order;

