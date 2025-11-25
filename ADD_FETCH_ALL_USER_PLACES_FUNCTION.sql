-- ============================================================================
-- OPTIMIZED: Fetch ALL user places in a single query
-- ============================================================================
-- This function returns ALL places a user has saved from ANY source
-- (my_places, favorites, place_list_items) in a single efficient query

CREATE OR REPLACE FUNCTION get_all_user_places(p_user_id UUID)
RETURNS TABLE (
    id UUID,
    name TEXT,
    address TEXT,
    city TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    mapbox_id TEXT,
    google_place_id TEXT,
    phone TEXT,
    rating DOUBLE PRECISION,
    user_ratings_total INTEGER,
    categories TEXT[],
    photo_urls TEXT[],
    open_hours JSONB,
    price_level TEXT,
    description_text TEXT,
    reservable BOOLEAN,
    serves_breakfast BOOLEAN,
    serves_lunch BOOLEAN,
    serves_dinner BOOLEAN,
    instagram TEXT,
    x TEXT,
    source TEXT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT ON (p.id)
        p.id,
        p.name,
        p.address,
        p.city,
        ST_Y(p.location::geometry) AS latitude,
        ST_X(p.location::geometry) AS longitude,
        p.mapbox_id,
        p.google_place_id,
        p.phone,
        p.rating,
        p.rating_count AS user_ratings_total,
        p.categories,
        p.photo_urls,
        p.open_hours,
        p.price_level,
        p.description AS description_text,
        p.reservable,
        p.serves_breakfast,
        p.serves_lunch,
        p.serves_dinner,
        p.instagram,
        p.twitter AS x,
        p.source,
        p.created_at,
        p.updated_at
    FROM places p
    WHERE p.id IN (
        -- From my_places
        SELECT place_id FROM my_places WHERE user_id = p_user_id
        UNION
        -- From favorites  
        SELECT place_id FROM favorites WHERE user_id = p_user_id
        UNION
        -- From place_list_items (via user's lists)
        SELECT pli.place_id 
        FROM place_list_items pli
        JOIN place_lists pl ON pli.list_id = pl.id
        WHERE pl.user_id = p_user_id
    )
    ORDER BY p.id, p.name;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Test the function
-- ============================================================================
SELECT COUNT(*) as total_places
FROM get_all_user_places('kKEEK3Snx4Yirp7jIi9FMyzEUWF2');

-- Should return at least 4 (your favorites)

-- See all places with details
SELECT id, name, address, city, latitude, longitude
FROM get_all_user_places('kKEEK3Snx4Yirp7jIi9FMyzEUWF2')
ORDER BY name;

-- ============================================================================
-- USAGE IN CODE
-- ============================================================================
/*
Swift code to call this function:

let response: [PlaceRecord] = try await supabase.client
    .rpc("get_all_user_places", params: ["p_user_id": userId])
    .execute()
    .value

Performance: Single query, single database round-trip!
Expected time: 50-200ms depending on place count
*/

-- ============================================================================
-- ALTERNATIVE: Optimized JOIN query (if RPC doesn't work)
-- ============================================================================
/*
-- This query can be used directly instead of the function:

SELECT DISTINCT ON (p.id)
    p.*,
    ST_Y(p.location::geometry) AS latitude,
    ST_X(p.location::geometry) AS longitude
FROM places p
WHERE p.id IN (
    SELECT place_id FROM my_places WHERE user_id = 'kKEEK3Snx4Yirp7jIi9FMyzEUWF2'
    UNION
    SELECT place_id FROM favorites WHERE user_id = 'kKEEK3Snx4Yirp7jIi9FMyzEUWF2'
    UNION
    SELECT pli.place_id 
    FROM place_list_items pli
    JOIN place_lists pl ON pli.list_id = pl.id
    WHERE pl.user_id = 'kKEEK3Snx4Yirp7jIi9FMyzEUWF2'
);
*/

