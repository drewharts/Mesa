# 🔍 **Debug: User ID Migration Not Working**

## **Step 1: Add the firebase_uid Column**

First, make sure you ran this SQL in Supabase:

```sql
ALTER TABLE users ADD COLUMN IF NOT EXISTS firebase_uid TEXT;
COMMENT ON COLUMN users.firebase_uid IS 'Original Firebase user ID for migration tracking';
```

## **Step 2: Check Current Database State**

Run these queries in Supabase SQL Editor:

```sql
-- Check if firebase_uid column exists
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
```

## **Step 3: Check Console Logs**

When you sign in, you should see these logs:

### **Expected Migration Logs:**
```
🔄 Checking for existing user profile with email: drewharts8@gmail.com
🎯 Found existing user profile! Migrating from Firebase UID: [OLD_ID] to Supabase UID: [NEW_ID]
🔄 Starting user migration: [OLD_ID] → [NEW_ID]
✅ User migration completed successfully
```

### **If You See This (No Migration):**
```
🔄 Checking for existing user profile with email: drewharts8@gmail.com
👤 No existing user found, creating new profile
```
**This means:** The migration logic didn't find your existing user profile.

## **Step 4: Debug Why Migration Isn't Triggered**

### **Possible Issues:**

#### **1. Email Case Sensitivity**
```sql
-- Check if email case matches
SELECT email FROM users WHERE LOWER(email) = LOWER('drewharts8@gmail.com');
```

#### **2. User Doesn't Exist in users Table**
```sql
-- Check if user exists at all
SELECT COUNT(*) FROM users WHERE email LIKE '%drewharts8%';
```

#### **3. Migration Already Ran**
```sql
-- Check if firebase_uid is set (indicates migration ran)
SELECT id, firebase_uid, email FROM users WHERE firebase_uid IS NOT NULL;
```

## **Step 5: Manual Migration Test**

If the automatic migration isn't working, test it manually:

```sql
-- 1. Get your Supabase auth ID (from console logs)
-- Look for: "👤 User ID: EC85766C-5C52-409A-8B2B-8B484E95E034"

-- 2. Get your current user ID
SELECT id, email FROM users WHERE email = 'drewharts8@gmail.com';

-- 3. Manually migrate (replace with your actual IDs)
UPDATE users
SET id = 'EC85766C-5C52-409A-8B2B-8B484E95E034',  -- New Supabase auth ID
    firebase_uid = id  -- Preserve old ID
WHERE email = 'drewharts8@gmail.com';
```

## **Step 6: Check Migration Results**

After migration, verify:

```sql
-- Check that IDs now match
SELECT
    au.id as auth_id,
    u.id as user_id,
    u.firebase_uid as old_firebase_id,
    au.email
FROM auth.users au
LEFT JOIN users u ON au.email = u.email
WHERE au.email = 'drewharts8@gmail.com';
```

**Expected result:** `auth_id` should equal `user_id`

## **Common Issues & Fixes:**

### **Issue 1: Column Not Added**
**Symptom:** "Could not find the 'firebase_uid' column"
**Fix:** Run the ALTER TABLE statement above

### **Issue 2: User Not Found**
**Symptom:** "No existing user found, creating new profile"
**Fix:** Check email spelling/case, verify user exists in users table

### **Issue 3: Migration Already Ran**
**Symptom:** User has `firebase_uid` set but IDs don't match
**Fix:** The migration ran but failed - check error logs

### **Issue 4: RLS Blocking Update**
**Symptom:** Migration starts but fails on UPDATE
**Fix:** Temporarily disable RLS, run migration, re-enable RLS

## **Quick Test:**

1. **Add firebase_uid column** (if not done)
2. **Check current user data** with SQL above
3. **Sign in again** and check console logs
4. **Verify migration results** with final SQL query

**What's the output of the SQL queries?** That will tell us exactly what's happening! 🔍</contents>
</xai:function_call<parameter name="file_path">/Users/drewhartsfield/Desktop/Loc/MIGRATION_DEBUG_STEPS.md
