-- Add firebase_uid column to track original Firebase user IDs during migration

ALTER TABLE users ADD COLUMN IF NOT EXISTS firebase_uid TEXT;

-- Add comment explaining the column
COMMENT ON COLUMN users.firebase_uid IS 'Original Firebase user ID for migration tracking';

-- Create index for faster lookups if needed
CREATE INDEX IF NOT EXISTS users_firebase_uid_idx ON users (firebase_uid);

-- Verify the column was added
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'users' AND column_name = 'firebase_uid';</contents>
</xai:function_call<parameter name="file_path">/Users/drewhartsfield/Desktop/Loc/ADD_FIREBASE_UID_COLUMN.sql