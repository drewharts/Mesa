-- DEBUG: Check current user state after login
-- The system is trying to fetch user with Supabase UID: C9DFA19E-B1B0-4EF1-8697-E448BC606CC7

-- 1. Check if existing user exists
SELECT id, email, firebase_uid, supabase_uid
FROM users
WHERE email = 'drewharts8@gmail.com';

-- 2. Check if user was created with Supabase UID
SELECT id, email, firebase_uid, supabase_uid
FROM users
WHERE id = 'C9DFA19E-B1B0-4EF1-8697-E448BC606CC7'
   OR supabase_uid = 'C9DFA19E-B1B0-4EF1-8697-E448BC606CC7';

-- 3. Check auth.users table
SELECT id, email, created_at
FROM auth.users
WHERE id = 'C9DFA19E-B1B0-4EF1-8697-E448BC606CC7';

-- 4. Check all users with similar emails (in case of case sensitivity)
SELECT id, email, firebase_uid, supabase_uid
FROM users
WHERE email ILIKE '%drewharts8%';

-- 5. Check place_lists for the Firebase UID (if it exists)
SELECT id, user_id, name
FROM place_lists
WHERE user_id = 'kKEEK3Snx4Yirp7jIi9FMyzEUWF2';