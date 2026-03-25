-- ============================================================================
-- Function: get_paid_list_places_with_access_check
-- ============================================================================
-- Returns places in a list with access control for paid lists.
-- If user is owner, collaborator, or purchaser: returns all places.
-- Otherwise: returns only the first N places (preview_place_count) with
-- is_preview = true so the client knows to show the paywall overlay.
-- Free lists always return all places.
-- ============================================================================

CREATE OR REPLACE FUNCTION get_paid_list_places_with_access_check(
    p_user_id TEXT,
    p_list_id TEXT,
    p_page INT,
    p_page_size INT
)
RETURNS TABLE(
    place_id TEXT,
    name TEXT,
    coordinate TEXT,
    image_url TEXT,
    place_type TEXT,
    city TEXT,
    is_preview BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_price_tier TEXT;
    v_preview_count INT;
    v_has_access BOOLEAN;
BEGIN
    -- Get list pricing info
    SELECT pl.price_tier, pl.preview_place_count
    INTO v_price_tier, v_preview_count
    FROM place_lists pl
    WHERE pl.id = p_list_id::UUID;

    -- Free list: return all places, no preview restriction
    IF v_price_tier IS NULL THEN
        RETURN QUERY
        SELECT
            pli.place_id::TEXT,
            p.name,
            ST_AsText(p.coordinate) AS coordinate,
            p.image_url,
            p.place_type,
            p.city,
            FALSE AS is_preview
        FROM place_list_items pli
        JOIN places p ON p.place_id = pli.place_id
        WHERE pli.list_id = p_list_id::UUID
        ORDER BY pli.added_at DESC
        OFFSET (p_page - 1) * p_page_size
        LIMIT p_page_size;
        RETURN;
    END IF;

    -- Paid list: check access
    SELECT check_list_purchase(p_user_id, p_list_id) INTO v_has_access;

    IF v_has_access THEN
        -- Full access: return all places
        RETURN QUERY
        SELECT
            pli.place_id::TEXT,
            p.name,
            ST_AsText(p.coordinate) AS coordinate,
            p.image_url,
            p.place_type,
            p.city,
            FALSE AS is_preview
        FROM place_list_items pli
        JOIN places p ON p.place_id = pli.place_id
        WHERE pli.list_id = p_list_id::UUID
        ORDER BY pli.added_at DESC
        OFFSET (p_page - 1) * p_page_size
        LIMIT p_page_size;
    ELSE
        -- Preview only: return first N places marked as preview
        RETURN QUERY
        SELECT
            pli.place_id::TEXT,
            p.name,
            ST_AsText(p.coordinate) AS coordinate,
            p.image_url,
            p.place_type,
            p.city,
            TRUE AS is_preview
        FROM place_list_items pli
        JOIN places p ON p.place_id = pli.place_id
        WHERE pli.list_id = p_list_id::UUID
        ORDER BY pli.added_at DESC
        LIMIT v_preview_count;
    END IF;
END;
$function$;

GRANT EXECUTE ON FUNCTION get_paid_list_places_with_access_check(TEXT, TEXT, INT, INT) TO authenticated;
