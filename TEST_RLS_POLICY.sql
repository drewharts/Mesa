-- Test the RLS policy to see if it allows user profile updates
-- Run these queries in Supabase SQL Editor while logged in

-- First, check what your current auth context is:
SELECT
    auth.uid() as current_auth_uid,
    auth.jwt() ->> 'email' as auth_email;

-- Check your current user profile:
SELECT id, email, firebase_uid
FROM users
WHERE email = 'drewharts8@gmail.com';

-- Try to update your profile (this should work with the new policy):
UPDATE users
SET firebase_uid = 'test-firebase-uid'
WHERE email = 'drewharts8@gmail.com';

-- Check if the update worked:
SELECT id, email, firebase_uid
FROM users
WHERE email = 'drewharts8@gmail.com';

-- Test the exact migration update query:
UPDATE users
SET
    id = 'ec85766c-5c52-409a-8b2b-8b484e95e034',
    firebase_uid = 'kKEEK3Snx4Yirp7jIi9FMyzEUWF2'
WHERE email = 'drewharts8@gmail.com';

-- Verify the final state:
SELECT id, email, firebase_uid
FROM users
WHERE email = 'drewharts8@gmail.com';
