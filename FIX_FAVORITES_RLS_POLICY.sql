-- Fix the favorites RLS policy to handle both user_id and supabase_uid
-- This allows users to access their favorites whether they're identified by
-- their profile ID (user_id) or their Supabase auth ID (supabase_uid)

-- First, let's check the current policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies 
WHERE tablename = 'favorites';

-- Check if RLS is enabled
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'favorites';

-- Check the current user and auth context
SELECT auth.uid() as current_auth_uid;

-- Let's see what's in the favorites table
SELECT COUNT(*) as total_favorites FROM favorites;

-- Let's see what user_ids exist in favorites
SELECT DISTINCT user_id, COUNT(*) as count 
FROM favorites 
GROUP BY user_id 
ORDER BY count DESC 
LIMIT 10;

-- Drop the existing policies
DROP POLICY IF EXISTS favorites_select_policy ON favorites;
DROP POLICY IF EXISTS favorites_insert_policy ON favorites;
DROP POLICY IF EXISTS favorites_delete_policy ON favorites;

-- Create new policies that check both user_id and supabase_uid
CREATE POLICY favorites_select_policy ON favorites
    FOR SELECT
    USING (
        -- Allow if user_id matches the auth.uid() (for new users)
        user_id = auth.uid()::text OR
        -- Allow if there's a matching user with this supabase_uid (for migrated users)
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = favorites.user_id 
            AND users.supabase_uid = auth.uid()::text
        ) OR
        -- Allow if user_id is in following relationship (for friends' favorites)
        user_id IN (SELECT following_id FROM following WHERE follower_id::text = auth.uid()::text)
    );

CREATE POLICY favorites_insert_policy ON favorites
    FOR INSERT
    WITH CHECK (
        user_id = auth.uid()::text OR
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = favorites.user_id 
            AND users.supabase_uid = auth.uid()::text
        )
    );

CREATE POLICY favorites_delete_policy ON favorites
    FOR DELETE
    USING (
        user_id = auth.uid()::text OR
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = favorites.user_id 
            AND users.supabase_uid = auth.uid()::text
        )
    );

-- Test the policy by trying to select favorites
SELECT COUNT(*) as accessible_favorites FROM favorites;

-- If that still doesn't work, let's temporarily disable RLS to test
-- ALTER TABLE favorites DISABLE ROW LEVEL SECURITY;
-- SELECT COUNT(*) as total_without_rls FROM favorites;
-- ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;
