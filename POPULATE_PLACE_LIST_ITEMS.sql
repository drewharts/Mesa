-- ============================================================================
-- POPULATE place_list_items TABLE FROM FIREBASE DATA
-- ============================================================================
-- This script helps migrate place list data from Firebase to Supabase
-- Run this in your Supabase SQL Editor

-- Step 1: Check current state
-- Run this first to see what data you have
SELECT 
    'place_lists' as table_name,
    COUNT(*) as record_count
FROM place_lists
UNION ALL
SELECT 
    'place_list_items' as table_name,
    COUNT(*) as record_count
FROM place_list_items
UNION ALL
SELECT 
    'places' as table_name,
    COUNT(*) as record_count
FROM places;

-- Expected output:
-- place_lists: 51 records (you have this)
-- place_list_items: ??? (probably 0 - needs population)
-- places: ??? (should have your places)

-- ============================================================================
-- Step 2: Verify place_lists structure
-- ============================================================================
SELECT id, name, user_id 
FROM place_lists 
WHERE user_id = 'kKEEK3Snx4Yirp7jIi9FMyzEUWF2'
ORDER BY sort_order
LIMIT 5;

-- ============================================================================
-- Step 3: Check if any place_list_items exist
-- ============================================================================
SELECT 
    pli.id,
    pl.name as list_name,
    p.name as place_name,
    pli.sort_order
FROM place_list_items pli
JOIN place_lists pl ON pli.list_id = pl.id
JOIN places p ON pli.place_id = p.id
WHERE pl.user_id = 'kKEEK3Snx4Yirp7jIi9FMyzEUWF2'
LIMIT 10;

-- ============================================================================
-- Step 4: MANUAL INSERTION EXAMPLE
-- ============================================================================
-- If place_list_items table is empty, you'll need to populate it
-- Here's the structure for manual insertion:

/*
INSERT INTO place_list_items (list_id, place_id, sort_order)
VALUES 
    -- Example: Add OX Restaurant to Shanghai list
    ('7E8050C5-01A6-4309-9EC9-B2E28CA033D2', '45AAC214-A9C9-451C-B9FD-88DAE1CE80BB', 1),
    
    -- Example: Add Late August to NYC Bars list  
    ('40AB3349-4E5D-4193-AD58-78D825DE68F9', 'CAE88289-1225-4DE4-84A6-9DA978AAAFA7', 1),
    
    -- Example: Add Kisa to NYC Bars list
    ('40AB3349-4E5D-4193-AD58-78D825DE68F9', 'DB8D1D60-9AE3-42F2-AED3-5DC0F0934D37', 2),
    
    -- Example: Add La Cabra to NYC Bars list
    ('40AB3349-4E5D-4193-AD58-78D825DE68F9', 'DF77405E-A8D9-4850-8619-FF967D0B35A5', 3);
*/

-- ============================================================================
-- Step 5: POPULATE FROM FIREBASE EXPORT (If you have JSON)
-- ============================================================================
-- If you exported Firebase data to JSON, you can use jsonb_to_recordset:

/*
-- Example structure:
WITH firebase_data AS (
    SELECT * FROM jsonb_to_recordset('[
        {"list_id": "xxx", "place_id": "yyy", "sort_order": 1},
        {"list_id": "xxx", "place_id": "zzz", "sort_order": 2}
    ]'::jsonb) AS (
        list_id TEXT,
        place_id TEXT,
        sort_order INTEGER
    )
)
INSERT INTO place_list_items (list_id, place_id, sort_order)
SELECT 
    list_id::UUID,
    place_id::UUID,
    sort_order
FROM firebase_data
ON CONFLICT (list_id, place_id) DO NOTHING;
*/

-- ============================================================================
-- WORKAROUND: Add favorites to "All Favorites" list
-- ============================================================================
-- This creates a virtual list from your favorites so they appear somewhere

/*
-- 1. Create an "All Favorites" list if it doesn't exist
INSERT INTO place_lists (id, user_id, name, description, is_public, sort_order)
VALUES (
    gen_random_uuid(),
    'kKEEK3Snx4Yirp7jIi9FMyzEUWF2',
    'All Favorites',
    'Automatically generated from favorites',
    false,
    -1  -- Sort first
)
ON CONFLICT DO NOTHING
RETURNING id;

-- 2. Get the list ID (from above query result)
-- 3. Add all favorites to this list
WITH favorites_list AS (
    SELECT id FROM place_lists 
    WHERE user_id = 'kKEEK3Snx4Yirp7jIi9FMyzEUWF2' 
    AND name = 'All Favorites'
    LIMIT 1
)
INSERT INTO place_list_items (list_id, place_id, sort_order)
SELECT 
    fl.id,
    f.place_id::UUID,
    ROW_NUMBER() OVER (ORDER BY f.timestamp DESC) as sort_order
FROM favorites f
CROSS JOIN favorites_list fl
WHERE f.user_id = 'kKEEK3Snx4Yirp7jIi9FMyzEUWF2'
ON CONFLICT (list_id, place_id) DO NOTHING;
*/

-- ============================================================================
-- DIAGNOSTIC: See what favorites you have
-- ============================================================================
SELECT 
    f.user_id,
    f.place_id,
    p.name as place_name,
    p.address,
    p.city
FROM favorites f
JOIN places p ON f.place_id::UUID = p.id::UUID  
WHERE f.user_id = 'kKEEK3Snx4Yirp7jIi9FMyzEUWF2';

-- Expected: 4 favorites (OX Restaurant, Late August, Kisa, La Cabra Bakery)

-- ============================================================================
-- SUMMARY
-- ============================================================================
/*
The issue is that place_lists exist in Supabase (51 lists), but:
1. The places array in each list is empty
2. The place_list_items table needs to be populated

Options:
A. Export Firebase data and import to place_list_items
B. Manually add key places to important lists
C. Use favorites as a starting point
D. Build UI in app to add places to lists (long-term solution)

Recommended Quick Fix:
Run the "All Favorites" workaround above to create at least one list with places.
*/

