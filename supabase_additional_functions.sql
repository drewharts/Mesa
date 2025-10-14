-- Additional Supabase Functions for Mesa App
-- Run this after the main schema and RLS policies

-- ============================================================================
-- Get Average Rating for a Place
-- ============================================================================
CREATE OR REPLACE FUNCTION get_average_rating(p_place_id UUID)
RETURNS TABLE (average_rating DOUBLE PRECISION) AS $$
BEGIN
    RETURN QUERY
    SELECT AVG(
        CASE 
            WHEN type = 'restaurant' THEN (
                (COALESCE(food_rating, 0) + COALESCE(service_rating, 0) + 
                 COALESCE(ambiance_rating, 0) + COALESCE(value_rating, 0)) / 4.0
            )
            WHEN type = 'generic' THEN rating::DOUBLE PRECISION
            ELSE NULL
        END
    ) AS average_rating
    FROM reviews
    WHERE place_id = p_place_id
    AND (
        (type = 'restaurant' AND food_rating IS NOT NULL) OR
        (type = 'generic' AND rating IS NOT NULL)
    );
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Get Review Count for a Place
-- ============================================================================
CREATE OR REPLACE FUNCTION get_review_count(p_place_id UUID)
RETURNS INTEGER AS $$
DECLARE
    review_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO review_count
    FROM reviews
    WHERE place_id = p_place_id;
    
    RETURN COALESCE(review_count, 0);
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Get User's Feed (reviews from following users)
-- ============================================================================
CREATE OR REPLACE FUNCTION get_user_feed(
    p_user_id UUID,
    p_limit INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    review_id UUID,
    place_id UUID,
    place_name TEXT,
    user_id UUID,
    user_name TEXT,
    review_text TEXT,
    rating DOUBLE PRECISION,
    timestamp TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.id AS review_id,
        r.place_id,
        p.name AS place_name,
        r.user_id,
        u.full_name AS user_name,
        r.text AS review_text,
        CASE 
            WHEN r.type = 'restaurant' THEN (
                (COALESCE(r.food_rating, 0) + COALESCE(r.service_rating, 0) + 
                 COALESCE(r.ambiance_rating, 0) + COALESCE(r.value_rating, 0)) / 4.0
            )
            WHEN r.type = 'generic' THEN r.rating::DOUBLE PRECISION
            ELSE NULL
        END AS rating,
        r.timestamp
    FROM reviews r
    JOIN places p ON r.place_id = p.id
    JOIN users u ON r.user_id = u.id
    WHERE r.user_id IN (
        SELECT following_id 
        FROM following 
        WHERE follower_id = p_user_id
    )
    OR r.user_id = p_user_id
    ORDER BY r.timestamp DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Get Trending Places (most saved/reviewed in last 7 days)
-- ============================================================================
CREATE OR REPLACE FUNCTION get_trending_places(
    p_user_location_lat DOUBLE PRECISION DEFAULT NULL,
    p_user_location_lng DOUBLE PRECISION DEFAULT NULL,
    p_radius_meters DOUBLE PRECISION DEFAULT 50000, -- 50km default
    p_limit INTEGER DEFAULT 20
)
RETURNS TABLE (
    place_id UUID,
    place_name TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    favorite_count BIGINT,
    review_count BIGINT,
    trending_score DOUBLE PRECISION
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id AS place_id,
        p.name AS place_name,
        p.latitude,
        p.longitude,
        COUNT(DISTINCT f.id) AS favorite_count,
        COUNT(DISTINCT r.id) AS review_count,
        (COUNT(DISTINCT f.id) * 2 + COUNT(DISTINCT r.id)) AS trending_score
    FROM places p
    LEFT JOIN favorites f ON p.id = f.place_id 
        AND f.timestamp > NOW() - INTERVAL '7 days'
    LEFT JOIN reviews r ON p.id = r.place_id 
        AND r.timestamp > NOW() - INTERVAL '7 days'
    WHERE 
        -- If location provided, filter by radius
        (p_user_location_lat IS NULL OR p_user_location_lng IS NULL) OR
        ST_DWithin(
            p.location,
            ST_SetSRID(ST_MakePoint(p_user_location_lng, p_user_location_lat), 4326)::geography,
            p_radius_meters
        )
    GROUP BY p.id, p.name, p.latitude, p.longitude
    HAVING (COUNT(DISTINCT f.id) + COUNT(DISTINCT r.id)) > 0
    ORDER BY trending_score DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Get Place Recommendations (based on following users' favorites)
-- ============================================================================
CREATE OR REPLACE FUNCTION get_place_recommendations(
    p_user_id UUID,
    p_limit INTEGER DEFAULT 20
)
RETURNS TABLE (
    place_id UUID,
    place_name TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    saved_by_count BIGINT,
    saved_by_users TEXT[]
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id AS place_id,
        p.name AS place_name,
        p.latitude,
        p.longitude,
        COUNT(DISTINCT f.user_id) AS saved_by_count,
        ARRAY_AGG(DISTINCT u.full_name) AS saved_by_users
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
    GROUP BY p.id, p.name, p.latitude, p.longitude
    ORDER BY saved_by_count DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Search Places by Name or City (with geospatial filtering)
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
    distance_meters DOUBLE PRECISION
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id AS place_id,
        p.name AS place_name,
        p.address,
        p.city,
        p.latitude,
        p.longitude,
        CASE 
            WHEN p_user_lat IS NOT NULL AND p_user_lng IS NOT NULL THEN
                ST_Distance(
                    p.location,
                    ST_SetSRID(ST_MakePoint(p_user_lng, p_user_lat), 4326)::geography
                )
            ELSE NULL
        END AS distance_meters
    FROM places p
    WHERE 
        -- Text search
        (
            p.name ILIKE '%' || p_search_term || '%' OR
            p.city ILIKE '%' || p_search_term || '%' OR
            p.address ILIKE '%' || p_search_term || '%'
        )
        -- Geospatial filter (if location provided)
        AND (
            (p_user_lat IS NULL OR p_user_lng IS NULL) OR
            ST_DWithin(
                p.location,
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
-- Get User Statistics
-- ============================================================================
CREATE OR REPLACE FUNCTION get_user_stats(p_user_id UUID)
RETURNS TABLE (
    favorites_count BIGINT,
    lists_count BIGINT,
    reviews_count BIGINT,
    followers_count BIGINT,
    following_count BIGINT,
    places_created_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        (SELECT COUNT(*) FROM favorites WHERE user_id = p_user_id) AS favorites_count,
        (SELECT COUNT(*) FROM place_lists WHERE user_id = p_user_id) AS lists_count,
        (SELECT COUNT(*) FROM reviews WHERE user_id = p_user_id) AS reviews_count,
        (SELECT COUNT(*) FROM following WHERE following_id = p_user_id) AS followers_count,
        (SELECT COUNT(*) FROM following WHERE follower_id = p_user_id) AS following_count,
        (SELECT COUNT(*) FROM my_places WHERE user_id = p_user_id) AS places_created_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Indexes for Performance
-- ============================================================================

-- Full-text search index for place names
CREATE INDEX IF NOT EXISTS idx_places_name_trgm ON places USING gin (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_places_city_trgm ON places USING gin (city gin_trgm_ops);

-- Enable trigram extension for fuzzy text search
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Composite indexes for common queries
CREATE INDEX IF NOT EXISTS idx_reviews_place_timestamp ON reviews(place_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_reviews_user_timestamp ON reviews(user_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_favorites_user_timestamp ON favorites(user_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_comments_review_timestamp ON comments(review_id, timestamp);

-- ============================================================================
-- Database Triggers for Notifications
-- ============================================================================

-- Trigger to create notification when someone reviews a place
CREATE OR REPLACE FUNCTION notify_place_owners_on_review()
RETURNS TRIGGER AS $$
BEGIN
    -- Notify users who have favorited this place
    INSERT INTO user_notifications (user_id, type, review_id, place_id, from_user_id, message, timestamp)
    SELECT DISTINCT
        f.user_id,
        'review',
        NEW.id,
        NEW.place_id,
        NEW.user_id,
        'Someone reviewed a place you saved',
        NOW()
    FROM favorites f
    WHERE f.place_id = NEW.place_id
    AND f.user_id != NEW.user_id;  -- Don't notify the reviewer
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_notify_on_review
    AFTER INSERT ON reviews
    FOR EACH ROW
    EXECUTE FUNCTION notify_place_owners_on_review();

-- Trigger to create notification when someone comments on your review
CREATE OR REPLACE FUNCTION notify_review_author_on_comment()
RETURNS TRIGGER AS $$
BEGIN
    -- Notify the review author
    INSERT INTO user_notifications (user_id, type, comment_id, review_id, place_id, from_user_id, message, timestamp)
    SELECT 
        r.user_id,
        'comment',
        NEW.id,
        NEW.review_id,
        r.place_id,
        NEW.user_id,
        'Someone commented on your review',
        NOW()
    FROM reviews r
    WHERE r.id = NEW.review_id
    AND r.user_id != NEW.user_id;  -- Don't notify if commenting on own review
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_notify_on_comment
    AFTER INSERT ON comments
    FOR EACH ROW
    EXECUTE FUNCTION notify_review_author_on_comment();

-- Trigger to create notification when someone likes your review
CREATE OR REPLACE FUNCTION notify_review_author_on_like()
RETURNS TRIGGER AS $$
BEGIN
    -- Notify the review author
    INSERT INTO user_notifications (user_id, type, review_id, from_user_id, message, timestamp)
    SELECT 
        r.user_id,
        'like',
        NEW.review_id,
        NEW.user_id,
        'Someone liked your review',
        NOW()
    FROM reviews r
    WHERE r.id = NEW.review_id
    AND r.user_id != NEW.user_id;  -- Don't notify if liking own review
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_notify_on_like
    AFTER INSERT ON review_likes
    FOR EACH ROW
    EXECUTE FUNCTION notify_review_author_on_like();

-- Trigger to create notification when someone follows you
CREATE OR REPLACE FUNCTION notify_user_on_follow()
RETURNS TRIGGER AS $$
BEGIN
    -- Notify the user being followed
    INSERT INTO user_notifications (user_id, type, from_user_id, message, timestamp)
    VALUES (
        NEW.following_id,
        'follow',
        NEW.follower_id,
        'Someone started following you',
        NOW()
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_notify_on_follow
    AFTER INSERT ON following
    FOR EACH ROW
    EXECUTE FUNCTION notify_user_on_follow();

-- ============================================================================
-- Complete!
-- ============================================================================
-- Run this script after supabase_schema.sql and supabase_rls_policies.sql

