-- ============================================================================
-- Function: get_all_user_list_metadata
-- ============================================================================
-- Returns lightweight metadata for ALL lists owned by a user.
-- Used to power instant client-side list search — no pagination, no
-- collaborator photos, no distance calc. Just the fields needed for
-- filtering and display in search results.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_all_user_list_metadata(p_user_id text)
RETURNS TABLE(
    list_id text,
    name text,
    is_public boolean,
    image text,
    city text,
    place_count bigint,
    created_at text,
    updated_at text,
    preview_photos text[]
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $function$
BEGIN
    IF lower(p_user_id) != lower(auth.uid()::text) THEN
        RAISE EXCEPTION 'unauthorized';
    END IF;

    RETURN QUERY
    SELECT
        pl.id::text AS list_id,
        pl.name,
        pl.is_public,
        pl.image,
        pl.city,
        (SELECT COUNT(*) FROM place_list_items pli WHERE pli.list_id = pl.id) AS place_count,
        pl.created_at::text,
        pl.updated_at::text,
        pp.photos AS preview_photos
    FROM place_lists pl
    LEFT JOIN LATERAL (
        SELECT ARRAY_AGG(photo) AS photos FROM (
            SELECT get_latest_review_photo(pli.place_id) AS photo
            FROM place_list_items pli
            WHERE pli.list_id = pl.id
            ORDER BY pli.sort_order ASC NULLS LAST
            LIMIT 3
        ) sub
        WHERE sub.photo IS NOT NULL
    ) pp ON true
    WHERE pl.user_id = p_user_id
    ORDER BY pl.updated_at DESC NULLS LAST;
END;
$function$;
