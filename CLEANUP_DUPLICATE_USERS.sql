-- CLEANUP: Remove duplicate user records created during failed migration

-- 1. Check for duplicate users with same email
SELECT id, email, firebase_uid, supabase_uid, created_at
FROM users
WHERE email = 'drewharts8@gmail.com'
ORDER BY created_at;

-- 2. Keep the ORIGINAL Firebase user (has firebase_uid, older created_at)
-- Delete the duplicate Supabase user (has supabase_uid = auth id, newer created_at)

-- DELETE THE DUPLICATE (replace with actual duplicate ID)
-- DELETE FROM users WHERE id = 'C9DFA19E-B1B0-4EF1-8697-E448BC606CC7';

-- 3. Verify only one user remains
SELECT id, email, firebase_uid, supabase_uid
FROM users
WHERE email = 'drewharts8@gmail.com';

-- 4. Check that place_lists still work with the remaining user
SELECT pl.id, pl.user_id, pl.name, u.email
FROM place_lists pl
JOIN users u ON pl.user_id = u.id
WHERE u.email = 'drewharts8@gmail.com';
