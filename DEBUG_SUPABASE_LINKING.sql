-- DEBUG: Check if supabase_uid column exists and RLS policies are working

-- 1. Check if supabase_uid column exists
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'users' AND column_name = 'supabase_uid';

-- 2. Check current user record
SELECT id, email, firebase_uid, supabase_uid
FROM users
WHERE email = 'drewharts8@gmail.com';

-- 3. Check RLS policies on users table
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE tablename = 'users';

-- 4. Test manual update (should work if RLS allows it)
-- Replace with your actual Supabase auth ID from login
UPDATE users
SET supabase_uid = 'your-supabase-auth-id-here'
WHERE email = 'drewharts8@gmail.com';

-- 5. Check if update worked
SELECT id, email, firebase_uid, supabase_uid
FROM users
WHERE email = 'drewharts8@gmail.com';

-- 6. Check current auth context (run this while signed in)
SELECT auth.uid() as current_auth_uid, auth.jwt() ->> 'email' as auth_email;
