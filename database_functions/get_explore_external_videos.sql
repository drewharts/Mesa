-- ============================================================================
-- Function: get_explore_external_videos
-- ============================================================================
-- Returns paginated external videos (TikTok/Instagram) from all users
-- for the global Explore feed. Ordered by most recently added first.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_explore_external_videos(
    p_limit int DEFAULT 20,
    p_offset int DEFAULT 0,
    p_city text DEFAULT NULL
)
RETURNS TABLE(
    external_place_id text,
    url text,
    source text,
    place_id text,
    place_name text,
    place_type text,
    city text,
    added_at timestamp without time zone,
    thumbnail_url text,
    place_photo_url text
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
    COALESCE(
        p.user_corrected_category,
        (SELECT cat FROM unnest(p.categories) AS cat
         WHERE LOWER(cat) NOT IN ('establishment', 'point_of_interest', 'food', 'store', 'place', 'health')
         LIMIT 1),
        p.categories[1],
        'Place'
    ) AS place_type,
    normalize_city_name(p.city) AS city,
    ep.added_at,
    ep.thumbnail_url,
    COALESCE(
        -- User review photo (highest quality, uploaded by users)
        (SELECT r.images[1]
         FROM reviews r
         WHERE r.place_id::text = ep.place_id
           AND r.images[1] IS NOT NULL
         ORDER BY r.timestamp DESC LIMIT 1),
        -- External review photo (Google/Serper photos)
        (SELECT (media_item->>'imageUrl')::text
         FROM external_reviews er
         CROSS JOIN LATERAL jsonb_array_elements(er.media) AS media_item
         WHERE er.place_id::text = ep.place_id
           AND (media_item->>'type')::text = 'image'
           AND (media_item->>'imageUrl') IS NOT NULL
         ORDER BY er.review_iso_date DESC LIMIT 1),
        -- Place thumbnail or photo array
        p.thumbnail_url,
        p.photo_urls[1]
    ) AS place_photo_url
FROM external_places ep
JOIN places p ON UPPER(ep.place_id) = UPPER(p.id::text)
JOIN users u ON ep.user_id = u.id
WHERE ep.url IS NOT NULL
  AND ep.url != ''
  AND (p_city IS NULL OR normalize_city_name(p.city) = p_city)
ORDER BY ep.added_at DESC NULLS LAST, ep.id DESC
LIMIT p_limit
OFFSET p_offset;
$function$;
