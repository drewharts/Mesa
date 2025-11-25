-- Modify RLS policy to allow user ID updates during migration
-- This allows users to update their profile even when auth.uid() != users.id
-- (which happens during Firebase → Supabase migration)

-- Drop the existing policy
DROP POLICY IF EXISTS users_update_policy ON users;

-- Create new policy that allows updates for:
-- 1. Normal case: auth.uid() = users.id
-- 2. Migration case: user owns the record by email (for Firebase migration)
CREATE POLICY users_update_policy ON users
    FOR UPDATE
    USING (
        auth.uid()::text = id::text  -- Normal case
        OR
        (
            auth.jwt() ->> 'email' = email  -- Migration case: user owns by email
            AND firebase_uid IS NOT NULL    -- Only during migration period
        )
    );

-- Alternative: Allow updates if user is authenticated and owns record by email
-- This is more permissive but safer than disabling RLS entirely
CREATE POLICY users_update_migration_policy ON users
    FOR UPDATE
    USING (
        auth.uid() IS NOT NULL  -- User is authenticated
        AND auth.jwt() ->> 'email' = email  -- User owns record by email
    );
