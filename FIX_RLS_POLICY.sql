-- FIX RLS POLICY: Allow account linking during migration
-- The current policy blocks updates because supabase_uid is null for existing users

DROP POLICY IF EXISTS users_update_policy ON users;

-- Allow updates when:
-- 1. User owns record by supabase_uid (normal authenticated users)
-- 2. User owns record by email (during migration when supabase_uid is null)
-- 3. User owns record by id (fallback)
CREATE POLICY users_update_policy ON users
    FOR UPDATE
    USING (
        -- Normal case: user owns record by supabase_uid
        auth.uid()::text = supabase_uid::text
        OR
        -- Migration case: user owns record by email (allows setting supabase_uid)
        (auth.uid() IS NOT NULL AND auth.jwt() ->> 'email' = email)
        OR
        -- Fallback: user owns record by id (for new users)
        auth.uid()::text = id::text
    );

-- Verify the policy
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE tablename = 'users';
