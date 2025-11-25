-- Check if ProfileData can read the supabase_uid field

-- Test query that ProfileData model should be able to decode
SELECT
    id,
    first_name,
    last_name,
    email,
    profile_photo_url,
    phone_number,
    full_name_lower,
    full_name,
    fcm_token,
    firebase_uid,
    supabase_uid
FROM users
WHERE email = 'drewharts8@gmail.com';

-- Test the exact query used by findExistingUserByEmail
SELECT * FROM users WHERE email = 'drewharts8@gmail.com';

-- Check column types
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'users'
ORDER BY ordinal_position;
