-- Create RPC function to handle user profile migration
-- This bypasses RLS policies during migration

CREATE OR REPLACE FUNCTION migrate_user_profile(old_user_id TEXT, new_user_id TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Update the user profile with new ID and firebase_uid
    UPDATE users
    SET
        id = new_user_id,
        firebase_uid = old_user_id
    WHERE id = old_user_id;

    -- Log the migration
    RAISE NOTICE 'Migrated user profile from % to %', old_user_id, new_user_id;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION migrate_user_profile(TEXT, TEXT) TO authenticated;
