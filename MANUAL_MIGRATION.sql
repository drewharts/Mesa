-- Manual migration for user drewharts8@gmail.com
-- Old Firebase ID: kKEEK3Snx4Yirp7jIi9FMyzEUWF2
-- New Supabase Auth ID: ec85766c-5c52-409a-8b2b-8b484e95e034

-- Step 1: Update the main user record
UPDATE users
SET
    id = 'ec85766c-5c52-409a-8b2b-8b484e95e034',  -- New Supabase auth ID
    firebase_uid = 'kKEEK3Snx4Yirp7jIi9FMyzEUWF2'  -- Preserve old Firebase ID
WHERE email = 'drewharts8@gmail.com';

-- Step 2: Update all related tables (if any exist)
-- Note: These will only update records that exist

UPDATE favorites
SET user_id = 'ec85766c-5c52-409a-8b2b-8b484e95e034'
WHERE user_id = 'kKEEK3Snx4Yirp7jIi9FMyzEUWF2';

UPDATE following
SET follower_id = 'ec85766c-5c52-409a-8b2b-8b484e95e034'
WHERE follower_id = 'kKEEK3Snx4Yirp7jIi9FMyzEUWF2';

UPDATE following
SET following_id = 'ec85766c-5c52-409a-8b2b-8b484e95e034'
WHERE following_id = 'kKEEK3Snx4Yirp7jIi9FMyzEUWF2';

UPDATE place_lists
SET user_id = 'ec85766c-5c52-409a-8b2b-8b484e95e034'
WHERE user_id = 'kKEEK3Snx4Yirp7jIi9FMyzEUWF2';

UPDATE reviews
SET user_id = 'ec85766c-5c52-409a-8b2b-8b484e95e034'
WHERE user_id = 'kKEEK3Snx4Yirp7jIi9FMyzEUWF2';

UPDATE comments
SET user_id = 'ec85766c-5c52-409a-8b2b-8b484e95e034'
WHERE user_id = 'kKEEK3Snx4Yirp7jIi9FMyzEUWF2';

UPDATE my_places
SET user_id = 'ec85766c-5c52-409a-8b2b-8b484e95e034'
WHERE user_id = 'kKEEK3Snx4Yirp7jIi9FMyzEUWF2';

UPDATE external_places
SET user_id = 'ec85766c-5c52-409a-8b2b-8b484e95e034'
WHERE user_id = 'kKEEK3Snx4Yirp7jIi9FMyzEUWF2';

UPDATE place_notes
SET user_id = 'ec85766c-5c52-409a-8b2b-8b484e95e034'
WHERE user_id = 'kKEEK3Snx4Yirp7jIi9FMyzEUWF2';

UPDATE tik_tok_place_flags
SET user_id = 'ec85766c-5c52-409a-8b2b-8b484e95e034'
WHERE user_id = 'kKEEK3Snx4Yirp7jIi9FMyzEUWF2';

UPDATE user_notifications
SET user_id = 'ec85766c-5c52-409a-8b2b-8b484e95e034'
WHERE user_id = 'kKEEK3Snx4Yirp7jIi9FMyzEUWF2';

UPDATE review_likes
SET user_id = 'ec85766c-5c52-409a-8b2b-8b484e95e034'
WHERE user_id = 'kKEEK3Snx4Yirp7jIi9FMyzEUWF2';

-- Step 3: Verify the migration worked
SELECT
    au.id as auth_id,
    u.id as user_id,
    u.firebase_uid as old_firebase_id,
    au.email
FROM auth.users au
LEFT JOIN users u ON au.email = u.email
WHERE au.email = 'drewharts8@gmail.com';
