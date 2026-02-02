-- Migration: Create trips and trip_places tables
-- Date: 2026-02-01
-- Description: Add trip planning feature to Mesa

-- trips table
CREATE TABLE IF NOT EXISTS trips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    cover_image TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- trip_places table
CREATE TABLE IF NOT EXISTS trip_places (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    place_id TEXT NOT NULL REFERENCES places(id),
    day_date DATE NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(trip_id, place_id, day_date)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_trips_user_id ON trips(user_id);
CREATE INDEX IF NOT EXISTS idx_trips_start_date ON trips(start_date DESC);
CREATE INDEX IF NOT EXISTS idx_trip_places_trip_id ON trip_places(trip_id);
CREATE INDEX IF NOT EXISTS idx_trip_places_day_date ON trip_places(day_date);

-- Enable Row Level Security
ALTER TABLE trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE trip_places ENABLE ROW LEVEL SECURITY;

-- RLS Policies for trips
-- Users can only manage their own trips
CREATE POLICY "Users can view own trips"
    ON trips FOR SELECT
    USING (user_id = auth.uid()::text);

CREATE POLICY "Users can insert own trips"
    ON trips FOR INSERT
    WITH CHECK (user_id = auth.uid()::text);

CREATE POLICY "Users can update own trips"
    ON trips FOR UPDATE
    USING (user_id = auth.uid()::text)
    WITH CHECK (user_id = auth.uid()::text);

CREATE POLICY "Users can delete own trips"
    ON trips FOR DELETE
    USING (user_id = auth.uid()::text);

-- RLS Policies for trip_places
-- Users can only manage places in their own trips
CREATE POLICY "Users can view own trip places"
    ON trip_places FOR SELECT
    USING (trip_id IN (SELECT id FROM trips WHERE user_id = auth.uid()::text));

CREATE POLICY "Users can insert own trip places"
    ON trip_places FOR INSERT
    WITH CHECK (trip_id IN (SELECT id FROM trips WHERE user_id = auth.uid()::text));

CREATE POLICY "Users can update own trip places"
    ON trip_places FOR UPDATE
    USING (trip_id IN (SELECT id FROM trips WHERE user_id = auth.uid()::text))
    WITH CHECK (trip_id IN (SELECT id FROM trips WHERE user_id = auth.uid()::text));

CREATE POLICY "Users can delete own trip places"
    ON trip_places FOR DELETE
    USING (trip_id IN (SELECT id FROM trips WHERE user_id = auth.uid()::text));

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_trips_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update updated_at on trips table
DROP TRIGGER IF EXISTS trips_updated_at_trigger ON trips;
CREATE TRIGGER trips_updated_at_trigger
    BEFORE UPDATE ON trips
    FOR EACH ROW
    EXECUTE FUNCTION update_trips_updated_at();
