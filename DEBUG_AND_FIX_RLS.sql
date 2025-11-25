-- Debug and fix RLS policies for place_lists
-- This will help us understand what's happening and fix it

-- First, let's check the current policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies 
WHERE tablename = 'place_lists';

-- Let's also check if RLS is enabled
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'place_lists';

-- Check the current user and auth context
SELECT auth.uid() as current_auth_uid;

-- Let's see what's in the place_lists table (this should work if RLS is disabled)
SELECT COUNT(*) as total_place_lists FROM place_lists;

-- Let's see what user_ids exist in place_lists
SELECT DISTINCT user_id, COUNT(*) as count 
FROM place_lists 
GROUP BY user_id 
ORDER BY count DESC 
LIMIT 10;

-- Let's check if our specific user exists in the users table
SELECT id, first_name, last_name, supabase_uid 
FROM users 
WHERE id = 'kKEEK3Snx4Yirp7jIi9FMyzEUWF2' 
   OR supabase_uid = 'C9DFA19E-B1B0-4EF1-8697-E448BC606CC7';

-- Now let's completely drop and recreate the RLS policies with a simpler approach
DROP POLICY IF EXISTS place_lists_select_policy ON place_lists;
DROP POLICY IF EXISTS place_lists_insert_policy ON place_lists;
DROP POLICY IF EXISTS place_lists_update_policy ON place_lists;
DROP POLICY IF EXISTS place_lists_delete_policy ON place_lists;

-- Create a much simpler policy that should work
CREATE POLICY place_lists_select_policy ON place_lists
    FOR SELECT
    USING (
        -- Allow if user_id matches auth.uid()
        user_id = auth.uid()::text OR
        -- Allow if there's a matching user with this supabase_uid
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = place_lists.user_id 
            AND users.supabase_uid = auth.uid()::text
        ) OR
        -- Allow public lists
        is_public = true
    );

-- Create the other policies with the same logic
CREATE POLICY place_lists_insert_policy ON place_lists
    FOR INSERT
    WITH CHECK (
        user_id = auth.uid()::text OR
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = place_lists.user_id 
            AND users.supabase_uid = auth.uid()::text
        )
    );

CREATE POLICY place_lists_update_policy ON place_lists
    FOR UPDATE
    USING (
        user_id = auth.uid()::text OR
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = place_lists.user_id 
            AND users.supabase_uid = auth.uid()::text
        )
    );

CREATE POLICY place_lists_delete_policy ON place_lists
    FOR DELETE
    USING (
        user_id = auth.uid()::text OR
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = place_lists.user_id 
            AND users.supabase_uid = auth.uid()::text
        )
    );

-- Test the policy by trying to select place lists
SELECT COUNT(*) as accessible_place_lists FROM place_lists;

-- If that still doesn't work, let's temporarily disable RLS to test
-- ALTER TABLE place_lists DISABLE ROW LEVEL SECURITY;
-- SELECT COUNT(*) as total_without_rls FROM place_lists;
-- ALTER TABLE place_lists ENABLE ROW LEVEL SECURITY;
