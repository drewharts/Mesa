-- Check if firebase_uid column was added
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'users' AND column_name = 'firebase_uid';

-- Check current user data
SELECT id, firebase_uid, first_name, last_name, email, created_at
FROM users
WHERE email = 'drewharts8@gmail.com';

-- Check auth users table
SELECT id, email, created_at
FROM auth.users
WHERE email = 'drewharts8@gmail.com';

-- Check if migration actually ran (look for firebase_uid values)
SELECT id, firebase_uid, email
FROM users
WHERE firebase_uid IS NOT NULL;</contents>
</xai:function_call<parameter name="file_path">/Users/drewhartsfield/Desktop/Loc/DEBUG_MIGRATION_STATUS.sql
