-- Update RLS policy to work with supabase_uid column
-- This allows proper authentication while maintaining data integrity

-- Drop the existing policy
DROP POLICY IF EXISTS users_update_policy ON users;

-- Create new policy that allows operations based on supabase_uid
CREATE POLICY users_select_policy ON users
    FOR SELECT
    USING (true);

CREATE POLICY users_insert_policy ON users
    FOR INSERT
    WITH CHECK (auth.uid()::text = id::text);

CREATE POLICY users_update_policy ON users
    FOR UPDATE
    USING (
        auth.uid()::text = supabase_uid::text  -- User owns record by supabase_uid
        OR
        auth.uid()::text = id::text  -- Fallback for new users where id = supabase_uid
    );

CREATE POLICY users_delete_policy ON users
    FOR DELETE
    USING (
        auth.uid()::text = supabase_uid::text  -- User owns record by supabase_uid
        OR
        auth.uid()::text = id::text  -- Fallback for new users where id = supabase_uid
    );

-- Verify policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE tablename = 'users';
