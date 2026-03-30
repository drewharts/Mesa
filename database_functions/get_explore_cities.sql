-- ============================================================================
-- Function: get_explore_cities
-- ============================================================================
-- Returns cities that have external videos, ordered by video count.
-- Used for the city filter pills on the Explore feed.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_explore_cities(
    p_limit int DEFAULT 20
)
RETURNS TABLE(
    city text,
    video_count bigint
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $function$
SELECT
    p.city,
    COUNT(*) AS video_count
FROM external_places ep
JOIN places p ON UPPER(ep.place_id) = UPPER(p.id::text)
WHERE ep.url IS NOT NULL
  AND ep.url != ''
  AND p.city IS NOT NULL
  AND p.city != ''
GROUP BY p.city
ORDER BY video_count DESC
LIMIT p_limit;
$function$;
