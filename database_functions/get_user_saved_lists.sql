-- ============================================================================
-- Function: get_user_saved_lists
-- ============================================================================
-- Fetches lists saved by the current user, sorted by proximity to their
-- location. Returns the same column shape as LightweightPlaceList Codable
-- expects, plus owner_name, owner_photo_url, and is_saved = true.
--
-- Safety: only returns lists that are still public. If a creator makes
-- their list private, it stops appearing in the saver's saved lists.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_user_saved_lists(
    p_user_id text,
    p_latitude double precision,
    p_longitude double precision,
    p_page integer,
    p_page_size integer
)
RETURNS TABLE(
    list_id text,
    name text,
    is_public boolean,
    image text,
    created_at text,
    updated_at text,
    distance_meters double precision,
    place_count bigint,
    city text,
    description text,
    price_tier text,
    average_location text,
    owner_name text,
    owner_photo_url text,
    is_saved boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_user_location geometry;
BEGIN
    -- Verify the caller is requesting their own saved lists
    IF p_user_id != auth.uid()::text THEN
        RAISE EXCEPTION 'unauthorized';
    END IF;

    v_user_location := ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326);

    RETURN QUERY
    SELECT
        pl.id::text AS list_id,
        pl.name,
        pl.is_public,
        pl.image,
        pl.created_at::text,
        pl.updated_at::text,
        CASE
            WHEN pl.average_location IS NOT NULL
            THEN ST_Distance(
                pl.average_location::geography,
                v_user_location::geography
            )
            ELSE NULL
        END AS distance_meters,
        pc.cnt AS place_count,
        pl.city,
        pl.description,
        pl.price_tier,
        CASE
            WHEN pl.average_location IS NOT NULL
            THEN ST_AsText(pl.average_location)
            ELSE NULL
        END AS average_location,
        u.full_name AS owner_name,
        u.profile_photo_url AS owner_photo_url,
        true AS is_saved
    FROM saved_lists sl
    JOIN place_lists pl ON sl.list_id = pl.id
    JOIN users u ON pl.user_id = u.id
    LEFT JOIN LATERAL (
        SELECT COUNT(*) AS cnt FROM place_list_items pli WHERE pli.list_id = pl.id
    ) pc ON true
    WHERE sl.user_id = p_user_id
    AND pl.is_public = true
    ORDER BY
        CASE WHEN pl.average_location IS NOT NULL THEN 0 ELSE 1 END ASC,
        distance_meters ASC NULLS LAST,
        sl.saved_at DESC
    OFFSET (p_page - 1) * p_page_size
    LIMIT p_page_size;
END;
$function$;
