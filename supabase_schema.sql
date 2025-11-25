-- Mesa App - Supabase Database Schema
-- Run this in your Supabase SQL Editor to create the database structure
-- This replaces the Firebase Firestore collections with PostgreSQL + PostGIS

-- Enable PostGIS extension for geospatial queries
CREATE EXTENSION IF NOT EXISTS postgis;

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- USERS TABLE
-- ============================================================================
CREATE TABLE users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    first_name TEXT,
    last_name TEXT,
    full_name TEXT,
    full_name_lower TEXT GENERATED ALWAYS AS (LOWER(full_name)) STORED,
    profile_photo_url TEXT,
    fcm_token TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for user search by name
CREATE INDEX idx_users_full_name_lower ON users(full_name_lower);
CREATE INDEX idx_users_email ON users(email);

-- ============================================================================
-- PLACES TABLE (with PostGIS for geospatial queries)
-- ============================================================================
CREATE TABLE places (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    address TEXT,
    city TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    location GEOGRAPHY(POINT, 4326), -- PostGIS point for efficient spatial queries
    mapbox_id TEXT,
    google_place_id TEXT,
    phone_number TEXT,
    website TEXT,
    photo_urls TEXT[],
    open_hours JSONB, -- Store opening hours as JSON
    price_level INTEGER,
    rating DOUBLE PRECISION,
    user_ratings_total INTEGER,
    place_types TEXT[],
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Spatial index for geography queries (CRITICAL for performance)
CREATE INDEX idx_places_location ON places USING GIST(location);

-- Standard indexes
CREATE INDEX idx_places_name ON places(name);
CREATE INDEX idx_places_city ON places(city);
CREATE INDEX idx_places_mapbox_id ON places(mapbox_id);
CREATE INDEX idx_places_lat_lng ON places(latitude, longitude);

-- Auto-update location field from lat/lng
CREATE OR REPLACE FUNCTION update_place_location()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
        NEW.location = ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326)::geography;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_place_location
    BEFORE INSERT OR UPDATE ON places
    FOR EACH ROW
    EXECUTE FUNCTION update_place_location();

-- ============================================================================
-- FAVORITES TABLE
-- ============================================================================
CREATE TABLE favorites (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    place_id UUID NOT NULL REFERENCES places(id) ON DELETE CASCADE,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, place_id)
);

CREATE INDEX idx_favorites_user_id ON favorites(user_id);
CREATE INDEX idx_favorites_place_id ON favorites(place_id);
CREATE INDEX idx_favorites_timestamp ON favorites(timestamp DESC);

-- ============================================================================
-- MY_PLACES TABLE (user-created places)
-- ============================================================================
CREATE TABLE my_places (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    place_id UUID NOT NULL REFERENCES places(id) ON DELETE CASCADE,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, place_id)
);

CREATE INDEX idx_my_places_user_id ON my_places(user_id);
CREATE INDEX idx_my_places_place_id ON my_places(place_id);

-- ============================================================================
-- FOLLOWING/FOLLOWERS TABLE (unified)
-- ============================================================================
CREATE TABLE following (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    follower_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    following_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    followed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(follower_id, following_id),
    CHECK (follower_id != following_id) -- Can't follow yourself
);

CREATE INDEX idx_following_follower_id ON following(follower_id);
CREATE INDEX idx_following_following_id ON following(following_id);
CREATE INDEX idx_following_followed_at ON following(followed_at DESC);

-- ============================================================================
-- PLACE LISTS TABLE
-- ============================================================================
CREATE TABLE place_lists (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    cover_image_url TEXT,
    is_public BOOLEAN DEFAULT false,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_place_lists_user_id ON place_lists(user_id);
CREATE INDEX idx_place_lists_sort_order ON place_lists(user_id, sort_order);

-- ============================================================================
-- PLACE LIST ITEMS TABLE (many-to-many relationship)
-- ============================================================================
CREATE TABLE place_list_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    list_id UUID NOT NULL REFERENCES place_lists(id) ON DELETE CASCADE,
    place_id UUID NOT NULL REFERENCES places(id) ON DELETE CASCADE,
    sort_order INTEGER DEFAULT 0,
    added_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(list_id, place_id)
);

CREATE INDEX idx_place_list_items_list_id ON place_list_items(list_id);
CREATE INDEX idx_place_list_items_place_id ON place_list_items(place_id);
CREATE INDEX idx_place_list_items_sort_order ON place_list_items(list_id, sort_order);

-- ============================================================================
-- REVIEWS TABLE (combined restaurant and generic reviews)
-- ============================================================================
CREATE TABLE reviews (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    place_id UUID NOT NULL REFERENCES places(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('restaurant', 'generic')),
    
    -- Common fields
    rating INTEGER, -- 1-5 stars
    text TEXT,
    photo_urls TEXT[],
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Restaurant-specific fields (nullable for generic reviews)
    food_rating INTEGER CHECK (food_rating IS NULL OR (food_rating >= 1 AND food_rating <= 5)),
    service_rating INTEGER CHECK (service_rating IS NULL OR (service_rating >= 1 AND service_rating <= 5)),
    ambiance_rating INTEGER CHECK (ambiance_rating IS NULL OR (ambiance_rating >= 1 AND ambiance_rating <= 5)),
    value_rating INTEGER CHECK (value_rating IS NULL OR (value_rating >= 1 AND value_rating <= 5)),
    would_recommend BOOLEAN,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_reviews_user_id ON reviews(user_id);
CREATE INDEX idx_reviews_place_id ON reviews(place_id);
CREATE INDEX idx_reviews_timestamp ON reviews(timestamp DESC);
CREATE INDEX idx_reviews_type ON reviews(type);

-- ============================================================================
-- COMMENTS TABLE
-- ============================================================================
CREATE TABLE comments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    review_id UUID NOT NULL REFERENCES reviews(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    text TEXT NOT NULL,
    photo_urls TEXT[],
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_comments_review_id ON comments(review_id);
CREATE INDEX idx_comments_user_id ON comments(user_id);
CREATE INDEX idx_comments_timestamp ON comments(timestamp);

-- ============================================================================
-- REVIEW LIKES TABLE
-- ============================================================================
CREATE TABLE review_likes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    review_id UUID NOT NULL REFERENCES reviews(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(review_id, user_id)
);

CREATE INDEX idx_review_likes_review_id ON review_likes(review_id);
CREATE INDEX idx_review_likes_user_id ON review_likes(user_id);

-- ============================================================================
-- EXTERNAL PLACES TABLE (TikTok-sourced places)
-- ============================================================================
CREATE TABLE external_places (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    place_id UUID NOT NULL REFERENCES places(id) ON DELETE CASCADE,
    source TEXT NOT NULL DEFAULT 'tiktok',
    tiktok_videos JSONB, -- Array of TikTok video data
    added_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, place_id)
);

CREATE INDEX idx_external_places_user_id ON external_places(user_id);
CREATE INDEX idx_external_places_place_id ON external_places(place_id);
CREATE INDEX idx_external_places_source ON external_places(source);

-- ============================================================================
-- PLACE NOTES TABLE
-- ============================================================================
CREATE TABLE place_notes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    place_id UUID NOT NULL REFERENCES places(id) ON DELETE CASCADE,
    note TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, place_id)
);

CREATE INDEX idx_place_notes_user_id ON place_notes(user_id);
CREATE INDEX idx_place_notes_place_id ON place_notes(place_id);

-- ============================================================================
-- TIKTOK PLACE FLAGS TABLE
-- ============================================================================
CREATE TABLE tiktok_place_flags (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    place_id UUID NOT NULL REFERENCES places(id) ON DELETE CASCADE,
    reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_tiktok_place_flags_user_id ON tiktok_place_flags(user_id);
CREATE INDEX idx_tiktok_place_flags_place_id ON tiktok_place_flags(place_id);

-- ============================================================================
-- USER NOTIFICATIONS TABLE
-- ============================================================================
CREATE TABLE user_notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('review', 'comment', 'like', 'follow')),
    
    -- References to related entities
    review_id UUID REFERENCES reviews(id) ON DELETE CASCADE,
    comment_id UUID REFERENCES comments(id) ON DELETE CASCADE,
    place_id UUID REFERENCES places(id) ON DELETE CASCADE,
    from_user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    
    message TEXT,
    is_read BOOLEAN DEFAULT false,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_user_notifications_user_id ON user_notifications(user_id);
CREATE INDEX idx_user_notifications_is_read ON user_notifications(user_id, is_read);
CREATE INDEX idx_user_notifications_timestamp ON user_notifications(timestamp DESC);

-- ============================================================================
-- AUTO-UPDATE TIMESTAMPS
-- ============================================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to tables with updated_at column
CREATE TRIGGER trigger_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trigger_places_updated_at BEFORE UPDATE ON places FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trigger_place_lists_updated_at BEFORE UPDATE ON place_lists FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trigger_reviews_updated_at BEFORE UPDATE ON reviews FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trigger_place_notes_updated_at BEFORE UPDATE ON place_notes FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================================
-- STORED PROCEDURES FOR COMMON QUERIES
-- ============================================================================

-- Get places in viewport (with friends' places)
CREATE OR REPLACE FUNCTION get_map_places(
    p_user_id UUID,
    p_north_lat DOUBLE PRECISION,
    p_south_lat DOUBLE PRECISION,
    p_east_lng DOUBLE PRECISION,
    p_west_lng DOUBLE PRECISION
)
RETURNS TABLE (
    id UUID,
    name TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    saved_by_user_id UUID,
    timestamp TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    -- User's own favorites
    SELECT p.id, p.name, p.latitude, p.longitude, f.user_id AS saved_by_user_id, f.timestamp
    FROM places p
    JOIN favorites f ON p.id = f.place_id
    WHERE f.user_id = p_user_id
      AND p.latitude BETWEEN p_south_lat AND p_north_lat
      AND p.longitude BETWEEN p_west_lng AND p_east_lng
    UNION
    -- Following users' favorites
    SELECT p.id, p.name, p.latitude, p.longitude, f.user_id AS saved_by_user_id, f.timestamp
    FROM places p
    JOIN favorites f ON p.id = f.place_id
    JOIN following fo ON f.user_id = fo.following_id
    WHERE fo.follower_id = p_user_id
      AND p.latitude BETWEEN p_south_lat AND p_north_lat
      AND p.longitude BETWEEN p_west_lng AND p_east_lng;
END;
$$ LANGUAGE plpgsql;

-- Get nearby places using PostGIS
CREATE OR REPLACE FUNCTION get_nearby_places(
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION,
    p_radius_meters DOUBLE PRECISION DEFAULT 5000
)
RETURNS TABLE (
    id UUID,
    name TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    distance_meters DOUBLE PRECISION
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.name,
        p.latitude,
        p.longitude,
        ST_Distance(
            p.location,
            ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography
        ) AS distance_meters
    FROM places p
    WHERE ST_DWithin(
        p.location,
        ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
        p_radius_meters
    )
    ORDER BY distance_meters;
END;
$$ LANGUAGE plpgsql;

-- Get user's full list with places
CREATE OR REPLACE FUNCTION get_list_with_places(p_list_id UUID)
RETURNS TABLE (
    list_id UUID,
    list_name TEXT,
    place_id UUID,
    place_name TEXT,
    place_address TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pl.id AS list_id,
        pl.name AS list_name,
        p.id AS place_id,
        p.name AS place_name,
        p.address AS place_address,
        p.latitude,
        p.longitude
    FROM place_lists pl
    JOIN place_list_items pli ON pl.id = pli.list_id
    JOIN places p ON pli.place_id = p.id
    WHERE pl.id = p_list_id
    ORDER BY pli.sort_order;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- SCHEMA COMPLETE
-- ============================================================================
-- Next step: Set up Row-Level Security (RLS) policies in supabase_rls_policies.sql

