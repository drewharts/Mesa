-- ============================================================================
-- Function: get_explore_external_videos
-- ============================================================================
-- Returns paginated external videos (TikTok/Instagram) from all users
-- for the global Explore feed. Ordered by most recently added first.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_explore_external_videos(
    p_limit int DEFAULT 20,
    p_offset int DEFAULT 0
)
RETURNS TABLE(
    external_place_id text,
    url text,
    source text,
    place_id text,
    place_name text,
    user_id text,
    user_full_name text,
    user_profile_photo_url text,
    added_at timestamp without time zone
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $function$
SELECT
    ep.id AS external_place_id,
    ep.url,
    ep.source,
    ep.place_id,
    p.name AS place_name,
    ep.user_id,
    u.full_name AS user_full_name,
    u.profile_photo_url AS user_profile_photo_url,
    ep.added_at
FROM external_places ep
JOIN places p ON UPPER(ep.place_id) = UPPER(p.id::text)
JOIN users u ON ep.user_id = u.id
WHERE ep.url IS NOT NULL
  AND ep.url != ''
ORDER BY ep.added_at DESC NULLS LAST, ep.id DESC
LIMIT p_limit
OFFSET p_offset;
$function$;
