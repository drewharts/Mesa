-- ============================================================================
-- Function: get_creator_earnings_summary
-- ============================================================================
-- Aggregates purchase data for a list creator.
-- Returns one row per paid list with sales count and earnings,
-- plus a summary row (list_id = 'TOTAL') with overall totals.
-- ============================================================================

CREATE OR REPLACE FUNCTION get_creator_earnings_summary(
    p_creator_id TEXT
)
RETURNS TABLE(
    total_sales BIGINT,
    total_earnings_cents BIGINT,
    list_id TEXT,
    list_name TEXT,
    list_sales BIGINT,
    list_earnings_cents BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
    RETURN QUERY
    WITH per_list AS (
        SELECT
            pl.id::TEXT AS l_id,
            pl.name AS l_name,
            COUNT(lp.id) AS l_sales,
            COALESCE(SUM(lp.price_cents), 0) AS l_earnings
        FROM place_lists pl
        LEFT JOIN list_purchases lp ON lp.list_id = pl.id
        WHERE pl.user_id = p_creator_id
          AND pl.price_tier IS NOT NULL
        GROUP BY pl.id, pl.name
    ),
    totals AS (
        SELECT
            COALESCE(SUM(l_sales), 0) AS t_sales,
            COALESCE(SUM(l_earnings), 0) AS t_earnings
        FROM per_list
    )
    SELECT
        t.t_sales AS total_sales,
        t.t_earnings AS total_earnings_cents,
        p.l_id AS list_id,
        p.l_name AS list_name,
        p.l_sales AS list_sales,
        p.l_earnings AS list_earnings_cents
    FROM per_list p
    CROSS JOIN totals t
    ORDER BY p.l_sales DESC;
END;
$function$;

GRANT EXECUTE ON FUNCTION get_creator_earnings_summary(TEXT) TO authenticated;
