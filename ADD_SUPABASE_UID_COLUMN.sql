-- Add supabase_uid column to associate Supabase auth IDs with user profiles
ALTER TABLE users ADD COLUMN IF NOT EXISTS supabase_uid TEXT;

-- Add index for faster lookups
CREATE INDEX IF NOT EXISTS users_supabase_uid_idx ON users (supabase_uid);

-- Add comment explaining the column
COMMENT ON COLUMN users.supabase_uid IS 'Supabase auth user ID - matches auth.users.id';

-- Verify the column was added
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'users' AND column_name = 'supabase_uid';
