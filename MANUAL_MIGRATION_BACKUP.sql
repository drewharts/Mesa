-- MANUAL MIGRATION BACKUP: If automatic migration fails
-- Replace these IDs with your actual values

-- Your actual IDs (from previous query):
-- Old Firebase ID: kKEEK3Snx4Yirp7jIi9FMyzEUWF2
-- New Supabase Auth ID: ec85766c-5c52-409a-8b2b-8b484e95e034

-- Step 1: Insert new user record with Supabase ID
INSERT INTO users (
    id, first_name, last_name, email, profile_photo_url,
    phone_number, full_name_lower, full_name, firebase_uid, fcm_token
)
SELECT
    'ec85766c-5c52-409a-8b2b-8b484e95e034',  -- New Supabase ID
    first_name, last_name, email, profile_photo_url,
    phone_number, full_name_lower, full_name,
    'kKEEK3Snx4Yirp7jIi9FMyzEUWF2',  -- Old Firebase ID
    fcm_token
FROM users
WHERE id = 'kKEEK3Snx4Yirp7jIi9FMyzEUWF2';

-- Step 2: Update all related tables
UPDATE favorites SET user_id = 'ec85766c-5c52-409a-8b2b-8b484e95e034' WHERE user_id = 'kKEEK3Snx4Yirp7jIi9FMyzEUWF2';
UPDATE following SET follower_id = 'ec85766c-5c52-409a-8b2b-8b484e95e034' WHERE follower_id = 'kKEEK3Snx4Yirp7jIi9FMyzEUWF2';
UPDATE following SET following_id = 'ec85766c-5c52-409a-8b2b-8b484e95e034' WHERE following_id = 'kKEEK3Snx4Yirp7jIi9FMyzEUWF2';
UPDATE place_lists SET user_id = 'ec85766c-5c52-409a-8b2b-8b484e95e034' WHERE user_id = 'kKEEK3Snx4Yirp7jIi9FMyzEUWF2';
UPDATE reviews SET user_id = 'ec85766c-5c52-409a-8b2b-8b484e95e034' WHERE user_id = 'kKEEK3Snx4Yirp7jIi9FMyzEUWF2';
UPDATE comments SET user_id = 'ec85766c-5c52-409a-8b2b-8b484e95e034' WHERE user_id = 'kKEEK3Snx4Yirp7jIi9FMyzEUWF2';
UPDATE my_places SET user_id = 'ec85766c-5c52-409a-8b2b-8b484e95e034' WHERE user_id = 'kKEEK3Snx4Yirp7jIi9FMyzEUWF2';
UPDATE external_places SET user_id = 'ec85766c-5c52-409a-8b2b-8b484e95e034' WHERE user_id = 'kKEEK3Snx4Yirp7jIi9FMyzEUWF2';
UPDATE place_notes SET user_id = 'ec85766c-5c52-409a-8b2b-8b484e95e034' WHERE user_id = 'kKEEK3Snx4Yirp7jIi9FMyzEUWF2';
UPDATE tik_tok_place_flags SET user_id = 'ec85766c-5c52-409a-8b2b-8b484e95e034' WHERE user_id = 'kKEEK3Snx4Yirp7jIi9FMyzEUWF2';
UPDATE user_notifications SET user_id = 'ec85766c-5c52-409a-8b2b-8b484e95e034' WHERE user_id = 'kKEEK3Snx4Yirp7jIi9FMyzEUWF2';
UPDATE review_likes SET user_id = 'ec85766c-5c52-409a-8b2b-8b484e95e034' WHERE user_id = 'kKEEK3Snx4Yirp7jIi9FMyzEUWF2';

-- Step 3: Delete old user record
DELETE FROM users WHERE id = 'kKEEK3Snx4Yirp7jIi9FMyzEUWF2';

-- Step 4: Verify migration
SELECT id, email, firebase_uid FROM users WHERE email = 'drewharts8@gmail.com';
