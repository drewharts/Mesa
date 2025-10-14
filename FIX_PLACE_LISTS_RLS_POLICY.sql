-- Fix the place_lists RLS policy to handle both user_id and supabase_uid
-- This allows users to access their place lists whether they're identified by
-- their profile ID (user_id) or their Supabase auth ID (supabase_uid)

-- Drop the existing policy
DROP POLICY IF EXISTS place_lists_select_policy ON place_lists;

-- Create a new policy that checks both user_id and supabase_uid
CREATE POLICY place_lists_select_policy ON place_lists
    FOR SELECT
    USING (
        -- Allow if user_id matches the auth.uid() (for new users)
        user_id::text = auth.uid()::text OR
        -- Allow if supabase_uid matches the auth.uid() (for migrated users)
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = place_lists.user_id 
            AND users.supabase_uid = auth.uid()::text
        ) OR
        -- Allow public lists
        is_public = true
    );

-- Also update the other place_lists policies for consistency
DROP POLICY IF EXISTS place_lists_insert_policy ON place_lists;
CREATE POLICY place_lists_insert_policy ON place_lists
    FOR INSERT
    WITH CHECK (
        user_id::text = auth.uid()::text OR
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = place_lists.user_id 
            AND users.supabase_uid = auth.uid()::text
        )
    );

DROP POLICY IF EXISTS place_lists_update_policy ON place_lists;
CREATE POLICY place_lists_update_policy ON place_lists
    FOR UPDATE
    USING (
        user_id::text = auth.uid()::text OR
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = place_lists.user_id 
            AND users.supabase_uid = auth.uid()::text
        )
    );

DROP POLICY IF EXISTS place_lists_delete_policy ON place_lists;
CREATE POLICY place_lists_delete_policy ON place_lists
    FOR DELETE
    USING (
        user_id::text = auth.uid()::text OR
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = place_lists.user_id 
            AND users.supabase_uid = auth.uid()::text
        )
    );
