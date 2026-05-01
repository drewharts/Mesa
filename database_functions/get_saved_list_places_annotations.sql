-- ============================================================================
-- Function: get_saved_list_places_annotations
-- ============================================================================
-- Returns place annotations from lists saved by the current user.
-- 6th union source in get_visible_annotations_with_users pipeline.
--
-- Attributes annotations to the list creator (pl.user_id) so their profile
-- photo appears on the map pin. If a place appears in multiple saved lists
-- from different creators, all creator IDs are aggregated.
--
-- Safety: pl.is_public = true ensures that if a creator makes their list
-- private, saved list places stop appearing on savers' maps immediately.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_saved_list_places_annotations(
    p_user_id text,
    p_bbox geometry
)
RETURNS TABLE(id text, name text, coordinate geometry, user_ids text[], place_type text)
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
    -- Verify the caller is requesting their own saved list annotations
    IF p_user_id != auth.uid()::text THEN
        RAISE EXCEPTION 'unauthorized';
    END IF;

    RETURN QUERY
    SELECT
        pli.place_id AS id,
        p.name,
        p.location AS coordinate,
        array_agg(DISTINCT pl.user_id ORDER BY pl.user_id) AS user_ids,
        COALESCE(
            p.user_corrected_category,
            (SELECT cat FROM unnest(p.categories) AS cat
             WHERE LOWER(cat) NOT IN ('establishment', 'point_of_interest', 'food', 'store', 'place', 'health')
             LIMIT 1),
            p.categories[1],
            'Place'
        ) AS place_type
    FROM saved_lists sl
    JOIN place_lists pl ON sl.list_id = pl.id
    JOIN place_list_items pli ON pli.list_id = pl.id
    JOIN places p ON pli.place_id = p.id
    WHERE sl.user_id = p_user_id
    AND pl.is_public = true
    AND ST_Intersects(p.location, p_bbox)
    GROUP BY pli.place_id, p.name, p.location, p.categories, p.user_corrected_category;
END;
$function$;
