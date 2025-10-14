-- Helper Functions for Your Actual Supabase Schema
-- Run this after your schema and RLS policies are set up

-- ============================================================================
-- Get places in viewport with user's following favorites (optimized for map)
-- ============================================================================
CREATE OR REPLACE FUNCTION get_map_places_in_viewport(
    p_user_id UUID,
    p_north_lat DOUBLE PRECISION,
    p_south_lat DOUBLE PRECISION,
    p_east_lng DOUBLE PRECISION,
    p_west_lng DOUBLE PRECISION
)
RETURNS TABLE (
    place_id UUID,
    place_name TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    saved_by_user_id UUID,
    saved_at TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    -- User's own favorites in viewport
    SELECT 
        p.id AS place_id,
        p.name AS place_name,
        ST_Y(p.location::geometry) AS latitude,
        ST_X(p.location::geometry) AS longitude,
        f.user_id AS saved_by_user_id,
        f."timestamp" AS saved_at
    FROM places p
    JOIN favorites f ON p.id = f.place_id
    WHERE f.user_id = p_user_id
      AND ST_Y(p.location::geometry) BETWEEN p_south_lat AND p_north_lat
      AND ST_X(p.location::geometry) BETWEEN p_west_lng AND p_east_lng
    
    UNION ALL
    
    -- Following users' favorites in viewport
    SELECT 
        p.id AS place_id,
        p.name AS place_name,
        ST_Y(p.location::geometry) AS latitude,
        ST_X(p.location::geometry) AS longitude,
        f.user_id AS saved_by_user_id,
        f."timestamp" AS saved_at
    FROM places p
    JOIN favorites f ON p.id = f.place_id
    JOIN following fo ON f.user_id = fo.following_id
    WHERE fo.follower_id = p_user_id
      AND ST_Y(p.location::geometry) BETWEEN p_south_lat AND p_north_lat
      AND ST_X(p.location::geometry) BETWEEN p_west_lng AND p_east_lng;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Get nearby places using PostGIS
-- ============================================================================
CREATE OR REPLACE FUNCTION get_nearby_places(
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION,
    p_radius_meters DOUBLE PRECISION DEFAULT 5000
)
RETURNS TABLE (
    place_id UUID,
    place_name TEXT,
    address TEXT,
    city TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    distance_meters DOUBLE PRECISION,
    rating FLOAT,
    categories TEXT[]
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id AS place_id,
        p.name AS place_name,
        p.address,
        p.city,
        ST_Y(p.location::geometry) AS latitude,
        ST_X(p.location::geometry) AS longitude,
        ST_Distance(
            p.location::geography,
            ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography
        ) AS distance_meters,
        p.rating,
        p.categories
    FROM places p
    WHERE ST_DWithin(
        p.location::geography,
        ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
        p_radius_meters
    )
    ORDER BY distance_meters;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Search places by name/city/address with optional location filtering
-- ============================================================================
CREATE OR REPLACE FUNCTION search_places(
    p_search_term TEXT,
    p_user_lat DOUBLE PRECISION DEFAULT NULL,
    p_user_lng DOUBLE PRECISION DEFAULT NULL,
    p_radius_meters DOUBLE PRECISION DEFAULT 50000,
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
    place_id UUID,
    place_name TEXT,
    address TEXT,
    city TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    distance_meters DOUBLE PRECISION,
    rating FLOAT,
    categories TEXT[]
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id AS place_id,
        p.name AS place_name,
        p.address,
        p.city,
        ST_Y(p.location::geometry) AS latitude,
        ST_X(p.location::geometry) AS longitude,
        CASE 
            WHEN p_user_lat IS NOT NULL AND p_user_lng IS NOT NULL THEN
                ST_Distance(
                    p.location::geography,
                    ST_SetSRID(ST_MakePoint(p_user_lng, p_user_lat), 4326)::geography
                )
            ELSE NULL
        END AS distance_meters,
        p.rating,
        p.categories
    FROM places p
    WHERE 
        -- Text search
        (
            p.name ILIKE '%' || p_search_term || '%' OR
            p.city ILIKE '%' || p_search_term || '%' OR
            p.address ILIKE '%' || p_search_term || '%'
        )
        -- Optional geospatial filter
        AND (
            (p_user_lat IS NULL OR p_user_lng IS NULL) OR
            ST_DWithin(
                p.location::geography,
                ST_SetSRID(ST_MakePoint(p_user_lng, p_user_lat), 4326)::geography,
                p_radius_meters
            )
        )
    ORDER BY 
        CASE 
            WHEN p_user_lat IS NOT NULL AND p_user_lng IS NOT NULL THEN distance_meters
            ELSE NULL
        END ASC NULLS LAST,
        p.name ASC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Get user statistics
-- ============================================================================
CREATE OR REPLACE FUNCTION get_user_stats(p_user_id UUID)
RETURNS TABLE (
    favorites_count BIGINT,
    lists_count BIGINT,
    reviews_count BIGINT,
    followers_count BIGINT,
    following_count BIGINT,
    my_places_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        (SELECT COUNT(*) FROM favorites WHERE user_id = p_user_id) AS favorites_count,
        (SELECT COUNT(*) FROM place_lists WHERE user_id = p_user_id) AS lists_count,
        (SELECT COUNT(*) FROM reviews WHERE user_id = p_user_id) AS reviews_count,
        (SELECT COUNT(*) FROM following WHERE following_id = p_user_id) AS followers_count,
        (SELECT COUNT(*) FROM following WHERE follower_id = p_user_id) AS following_count,
        (SELECT COUNT(*) FROM my_places WHERE user_id = p_user_id) AS my_places_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Get place list with all items
-- ============================================================================
CREATE OR REPLACE FUNCTION get_place_list_with_items(p_list_id UUID)
RETURNS TABLE (
    list_id UUID,
    list_name TEXT,
    list_description TEXT,
    is_public BOOLEAN,
    place_id UUID,
    place_name TEXT,
    place_address TEXT,
    city TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    rating FLOAT,
    sort_order INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pl.id AS list_id,
        pl.name AS list_name,
        pl.description AS list_description,
        pl.is_public,
        p.id AS place_id,
        p.name AS place_name,
        p.address AS place_address,
        p.city,
        ST_Y(p.location::geometry) AS latitude,
        ST_X(p.location::geometry) AS longitude,
        p.rating,
        pli.sort_order
    FROM place_lists pl
    LEFT JOIN place_list_items pli ON pl.id = pli.list_id
    LEFT JOIN places p ON pli.place_id = p.id
    WHERE pl.id = p_list_id
    ORDER BY pli.sort_order NULLS LAST;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Get user's feed (reviews from following)
-- ============================================================================
CREATE OR REPLACE FUNCTION get_user_feed(
    p_user_id UUID,
    p_limit INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    review_id UUID,
    user_id UUID,
    user_first_name TEXT,
    user_last_name TEXT,
    profile_photo_url TEXT,
    place_id UUID,
    place_name TEXT,
    food_rating FLOAT,
    service_rating FLOAT,
    ambience_rating FLOAT,
    review_text TEXT,
    images TEXT[],
    review_timestamp TIMESTAMP,
    likes INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.id AS review_id,
        r.user_id,
        r.user_first_name,
        r.user_last_name,
        r.profile_photo_url,
        r.place_id,
        r.place_name,
        r.food_rating,
        r.service_rating,
        r.ambience_rating,
        r.review_text,
        r.images,
        r."timestamp" AS review_timestamp,
        r.likes
    FROM reviews r
    WHERE r.user_id IN (
        SELECT following_id 
        FROM following 
        WHERE follower_id = p_user_id
    )
    OR r.user_id = p_user_id
    ORDER BY r."timestamp" DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Get average rating for a place (from reviews)
-- ============================================================================
CREATE OR REPLACE FUNCTION get_place_average_rating(p_place_id UUID)
RETURNS FLOAT AS $$
DECLARE
    avg_rating FLOAT;
BEGIN
    SELECT AVG((food_rating + service_rating + ambience_rating) / 3.0)
    INTO avg_rating
    FROM reviews
    WHERE place_id = p_place_id
    AND food_rating IS NOT NULL
    AND service_rating IS NOT NULL
    AND ambience_rating IS NOT NULL;
    
    RETURN COALESCE(avg_rating, 0.0);
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Get trending places (most activity in last 7 days)
-- ============================================================================
CREATE OR REPLACE FUNCTION get_trending_places(
    p_user_lat DOUBLE PRECISION DEFAULT NULL,
    p_user_lng DOUBLE PRECISION DEFAULT NULL,
    p_radius_meters DOUBLE PRECISION DEFAULT 50000,
    p_limit INTEGER DEFAULT 20
)
RETURNS TABLE (
    place_id UUID,
    place_name TEXT,
    address TEXT,
    city TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    recent_favorites BIGINT,
    recent_reviews BIGINT,
    trending_score DOUBLE PRECISION
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id AS place_id,
        p.name AS place_name,
        p.address,
        p.city,
        ST_Y(p.location::geometry) AS latitude,
        ST_X(p.location::geometry) AS longitude,
        COUNT(DISTINCT f.id) FILTER (WHERE f."timestamp" > NOW() - INTERVAL '7 days') AS recent_favorites,
        COUNT(DISTINCT r.id) FILTER (WHERE r."timestamp" > NOW() - INTERVAL '7 days') AS recent_reviews,
        (COUNT(DISTINCT f.id) FILTER (WHERE f."timestamp" > NOW() - INTERVAL '7 days') * 2 + 
         COUNT(DISTINCT r.id) FILTER (WHERE r."timestamp" > NOW() - INTERVAL '7 days')) AS trending_score
    FROM places p
    LEFT JOIN favorites f ON p.id = f.place_id
    LEFT JOIN reviews r ON p.id = r.place_id
    WHERE 
        -- Optional location filter
        (p_user_lat IS NULL OR p_user_lng IS NULL) OR
        ST_DWithin(
            p.location::geography,
            ST_SetSRID(ST_MakePoint(p_user_lng, p_user_lat), 4326)::geography,
            p_radius_meters
        )
    GROUP BY p.id, p.name, p.address, p.city, p.location
    HAVING (COUNT(DISTINCT f.id) FILTER (WHERE f."timestamp" > NOW() - INTERVAL '7 days') + 
            COUNT(DISTINCT r.id) FILTER (WHERE r."timestamp" > NOW() - INTERVAL '7 days')) > 0
    ORDER BY trending_score DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Get place recommendations (based on what friends saved)
-- ============================================================================
CREATE OR REPLACE FUNCTION get_place_recommendations(
    p_user_id UUID,
    p_limit INTEGER DEFAULT 20
)
RETURNS TABLE (
    place_id UUID,
    place_name TEXT,
    address TEXT,
    city TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    saved_by_count BIGINT,
    saved_by_names TEXT[]
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id AS place_id,
        p.name AS place_name,
        p.address,
        p.city,
        ST_Y(p.location::geometry) AS latitude,
        ST_X(p.location::geometry) AS longitude,
        COUNT(DISTINCT f.user_id) AS saved_by_count,
        ARRAY_AGG(DISTINCT u.full_name) AS saved_by_names
    FROM places p
    JOIN favorites f ON p.id = f.place_id
    JOIN users u ON f.user_id = u.id
    WHERE f.user_id IN (
        SELECT following_id 
        FROM following 
        WHERE follower_id = p_user_id
    )
    -- Exclude places already saved by current user
    AND p.id NOT IN (
        SELECT place_id 
        FROM favorites 
        WHERE user_id = p_user_id
    )
    GROUP BY p.id, p.name, p.address, p.city, p.location
    ORDER BY saved_by_count DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Triggers for automatic notifications
-- ============================================================================

-- Trigger: Notify when someone reviews a place you saved
CREATE OR REPLACE FUNCTION notify_on_review()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO user_notifications (
        id, user_id, type, actor_id, actor_first_name, actor_last_name, 
        actor_profile_photo_url, place_id, place_name, review_id, "timestamp", is_read
    )
    SELECT 
        gen_random_uuid(),
        f.user_id,
        'review',
        NEW.user_id,
        NEW.user_first_name,
        NEW.user_last_name,
        NEW.profile_photo_url,
        NEW.place_id,
        NEW.place_name,
        NEW.id,
        NEW."timestamp",
        false
    FROM favorites f
    WHERE f.place_id = NEW.place_id
    AND f.user_id != NEW.user_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_notify_on_review ON reviews;
CREATE TRIGGER trigger_notify_on_review
    AFTER INSERT ON reviews
    FOR EACH ROW
    EXECUTE FUNCTION notify_on_review();

-- Trigger: Notify when someone comments on your review
CREATE OR REPLACE FUNCTION notify_on_comment()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO user_notifications (
        id, user_id, type, actor_id, place_id, review_id, comment_id, "timestamp", is_read
    )
    SELECT 
        gen_random_uuid(),
        r.user_id,
        'comment',
        NEW.user_id,
        NEW.place_id,
        NEW.review_id,
        NEW.id,
        NEW."timestamp",
        false
    FROM reviews r
    WHERE r.id = NEW.review_id
    AND r.user_id != NEW.user_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_notify_on_comment ON comments;
CREATE TRIGGER trigger_notify_on_comment
    AFTER INSERT ON comments
    FOR EACH ROW
    EXECUTE FUNCTION notify_on_comment();

-- Trigger: Notify when someone likes your review
CREATE OR REPLACE FUNCTION notify_on_review_like()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO user_notifications (
        id, user_id, type, actor_id, review_id, "timestamp", is_read
    )
    SELECT 
        gen_random_uuid(),
        r.user_id,
        'like',
        NEW.user_id,
        NEW.review_id,
        NEW."timestamp",
        false
    FROM reviews r
    WHERE r.id = NEW.review_id
    AND r.user_id != NEW.user_id;
    
    -- Also increment likes count on review
    UPDATE reviews
    SET likes = likes + 1
    WHERE id = NEW.review_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_notify_on_review_like ON review_likes;
CREATE TRIGGER trigger_notify_on_review_like
    AFTER INSERT ON review_likes
    FOR EACH ROW
    EXECUTE FUNCTION notify_on_review_like();

-- Trigger: Decrement likes on unlike
CREATE OR REPLACE FUNCTION decrement_review_likes()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE reviews
    SET likes = GREATEST(likes - 1, 0)
    WHERE id = OLD.review_id;
    
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_decrement_review_likes ON review_likes;
CREATE TRIGGER trigger_decrement_review_likes
    AFTER DELETE ON review_likes
    FOR EACH ROW
    EXECUTE FUNCTION decrement_review_likes();

-- Trigger: Notify when someone follows you
CREATE OR REPLACE FUNCTION notify_on_follow()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO user_notifications (
        id, user_id, type, actor_id, "timestamp", is_read
    )
    VALUES (
        gen_random_uuid(),
        NEW.following_id,
        'follow',
        NEW.follower_id,
        COALESCE(NEW.created_at, NOW()),
        false
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_notify_on_follow ON following;
CREATE TRIGGER trigger_notify_on_follow
    AFTER INSERT ON following
    FOR EACH ROW
    EXECUTE FUNCTION notify_on_follow();

-- ============================================================================
-- HELPER FUNCTIONS COMPLETE
-- ============================================================================

