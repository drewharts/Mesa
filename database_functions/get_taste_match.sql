-- ============================================================================
-- Function: get_taste_match  (MIGRATION - NOT YET APPLIED, needs approval)
-- ============================================================================
-- Taste match % between the signed-in user (auth.uid()) and p_other_user_id.
-- Pure SQL, no external/LLM calls. Returns only aggregate numbers, never the
-- other user's places.
--
-- A user's "taste set" = favorites + my_places + places in lists they own
--                        + imported TikTok places (external_places).
-- Signals (each 0..1):
--   place_overlap : shared places / smaller set size (sqrt-damped)   weight .40
--   category      : cosine similarity of place_types counts          weight .30
--   area          : cosine similarity of ~1 km grid cells (lat/lng)  weight .20
--   city          : cosine similarity of city counts                 weight .10
-- Sparse data: if either user has < 5 places, score is NULL and
-- enough_data = false (app shows "Not enough saves yet").
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_taste_match(p_other_user_id UUID)
RETURNS TABLE(
    score INTEGER,
    enough_data BOOLEAN,
    shared_places INTEGER,
    top_shared_category TEXT
)
LANGUAGE plpgsql
VOLATILE  -- uses a temp table
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_me UUID := auth.uid();
    v_n_me INT; v_n_other INT; v_shared INT;
    v_place DOUBLE PRECISION; v_cat DOUBLE PRECISION;
    v_area DOUBLE PRECISION; v_city DOUBLE PRECISION;
    v_top TEXT;
BEGIN
    IF v_me IS NULL OR p_other_user_id IS NULL OR v_me = p_other_user_id THEN
        RETURN QUERY SELECT NULL::INT, FALSE, 0, NULL::TEXT; RETURN;
    END IF;

    CREATE TEMP TABLE IF NOT EXISTS _tm_sets(uid UUID, place_id UUID) ON COMMIT DROP;
    TRUNCATE _tm_sets;
    INSERT INTO _tm_sets
    SELECT DISTINCT s.uid, s.place_id FROM (
        SELECT user_id AS uid, place_id FROM favorites      WHERE user_id IN (v_me, p_other_user_id)
        UNION ALL
        SELECT user_id, place_id FROM my_places              WHERE user_id IN (v_me, p_other_user_id)
        UNION ALL
        SELECT user_id, place_id FROM external_places        WHERE user_id IN (v_me, p_other_user_id)
        UNION ALL
        SELECT pl.user_id, pli.place_id
        FROM place_lists pl JOIN place_list_items pli ON pli.list_id = pl.id
        WHERE pl.user_id IN (v_me, p_other_user_id)
          AND (pl.user_id = v_me OR COALESCE(pl.is_public, true))
    ) s;

    SELECT COUNT(*) FILTER (WHERE uid = v_me), COUNT(*) FILTER (WHERE uid = p_other_user_id)
      INTO v_n_me, v_n_other FROM _tm_sets;
    SELECT COUNT(*) INTO v_shared FROM _tm_sets a JOIN _tm_sets b
      ON a.place_id = b.place_id AND a.uid = v_me AND b.uid = p_other_user_id;

    IF v_n_me < 5 OR v_n_other < 5 THEN
        RETURN QUERY SELECT NULL::INT, FALSE, v_shared, NULL::TEXT; RETURN;
    END IF;

    v_place := LEAST(1.0, sqrt(v_shared::float / LEAST(v_n_me, v_n_other)));

    -- Feature vectors: (kind, key) -> count per user
    WITH feats AS (
        SELECT t.uid, 'cat' AS kind, lower(pt) AS k
        FROM _tm_sets t JOIN places p ON p.id = t.place_id, unnest(p.place_types) pt
        WHERE lower(pt) NOT IN ('point_of_interest','establishment','food','store','premise','place')
        UNION ALL
        SELECT t.uid, 'area', round(p.latitude::numeric, 2)::text || ',' || round(p.longitude::numeric, 2)::text
        FROM _tm_sets t JOIN places p ON p.id = t.place_id
        WHERE p.latitude IS NOT NULL AND p.longitude IS NOT NULL
        UNION ALL
        SELECT t.uid, 'city', lower(trim(p.city))
        FROM _tm_sets t JOIN places p ON p.id = t.place_id
        WHERE COALESCE(trim(p.city), '') <> ''
    ), v AS (
        SELECT kind, k,
               COUNT(*) FILTER (WHERE uid = v_me)::float AS a,
               COUNT(*) FILTER (WHERE uid = p_other_user_id)::float AS b
        FROM feats GROUP BY kind, k
    ), cos AS (
        SELECT kind, SUM(a*b) / NULLIF(sqrt(SUM(a*a)) * sqrt(SUM(b*b)), 0) AS sim
        FROM v GROUP BY kind
    )
    SELECT COALESCE(MAX(sim) FILTER (WHERE kind='cat'), 0),
           COALESCE(MAX(sim) FILTER (WHERE kind='area'), 0),
           COALESCE(MAX(sim) FILTER (WHERE kind='city'), 0)
      INTO v_cat, v_area, v_city FROM cos;

    SELECT lower(pt) INTO v_top
    FROM _tm_sets a JOIN _tm_sets b ON a.place_id = b.place_id AND a.uid = v_me AND b.uid = p_other_user_id
    JOIN places p ON p.id = a.place_id, unnest(p.place_types) pt
    WHERE lower(pt) NOT IN ('point_of_interest','establishment','food','store','premise','place')
    GROUP BY lower(pt) ORDER BY COUNT(*) DESC LIMIT 1;

    RETURN QUERY SELECT
        GREATEST(1, LEAST(99, round(100 * (0.40*v_place + 0.30*v_cat + 0.20*v_area + 0.10*v_city))::INT)),
        TRUE, v_shared, v_top;
END;
$$;

REVOKE ALL ON FUNCTION public.get_taste_match(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_taste_match(UUID) TO authenticated;
