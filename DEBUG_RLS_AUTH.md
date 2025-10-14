# 🔍 **Debug: RLS Policy vs Auth Context**

## **Your RLS Policy for Users Table:**

```sql
CREATE POLICY users_insert_policy ON users
    FOR INSERT
    WITH CHECK (auth.uid()::text = id::text);
```

**This policy means:** "Users can only insert rows where the row's `id` matches their authenticated user ID (`auth.uid()`)"

## **The Issue:**

Your error shows:
1. ✅ **Authentication successful** - User signed in with Supabase
2. ❌ **Profile lookup failed** - "User profile not found (404)"  
3. ❌ **Profile creation failed** - "new row violates row-level security policy"

## **Debug Steps:**

### **Step 1: Check if Profile Actually Exists**

Run in Supabase SQL Editor:

```sql
-- Check if the user profile exists
SELECT id, first_name, last_name, email, created_at
FROM users
WHERE id = '7E996518-30EC-48CB-A6B1-BF5A51A7D88B';

-- Check by email too
SELECT id, email
FROM users
WHERE email = 'drewharts8@gmail.com';
```

### **Step 2: Check Auth Context**

If the profile doesn't exist, the issue is that `auth.uid()` doesn't match the ID being inserted. Let's debug:

```sql
-- Test what auth.uid() returns (run this while signed in)
SELECT auth.uid() as current_auth_uid;

-- Test the policy condition manually
SELECT
    '7E996518-30EC-48CB-A6B1-BF5A51A7D88B'::text as profile_id,
    auth.uid()::text as auth_uid,
    ('7E996518-30EC-48CB-A6B1-BF5A51A7D88B'::text = auth.uid()::text) as ids_match;
```

### **Step 3: Test Manual Insert**

If the IDs don't match, try inserting manually:

```sql
-- Try to insert with your current auth context
INSERT INTO users (id, first_name, last_name, email, full_name, full_name_lower)
VALUES (
    auth.uid()::text,  -- Use whatever auth.uid() returns
    'Test',
    'User',
    'test@example.com',
    'Test User',
    'test user'
);
```

### **Step 4: Fix the Auth Context Issue**

If `auth.uid()` is returning something different than your user ID, the issue might be:

1. **Session not properly set** in Supabase client
2. **Auth token expired** or invalid
3. **Wrong Supabase project** or keys

### **Step 5: Alternative Fix - Bypass RLS for Initial Creation**

If the auth context is broken, temporarily allow inserts:

```sql
-- Drop the restrictive policy temporarily
DROP POLICY users_insert_policy ON users;

-- Create a more permissive policy for testing
CREATE POLICY users_insert_policy_temp ON users
    FOR INSERT
    WITH CHECK (true);  -- Allow any authenticated user to insert

-- Now try signing in again
-- If it works, the issue was auth context

-- Clean up - restore the original policy
DROP POLICY users_insert_policy_temp ON users;
CREATE POLICY users_insert_policy ON users
    FOR INSERT
    WITH CHECK (auth.uid()::text = id::text);
```

## **Understanding Your Policy:**

Your policy `auth.uid()::text = id::text` is **correct and secure**. It ensures users can only create profiles for themselves.

The issue is likely that `auth.uid()` is returning a different value than expected, or the auth context isn't working properly.

## **Quick Diagnosis:**

**Run Step 1 first** - check if the profile exists.  
**If it doesn't exist:** Run Step 2 to check the auth context.  
**If auth.uid() is wrong:** Your Supabase session might not be properly set.

**Start with checking if the profile actually exists!** 🔍</contents>
</xai:function_call<parameter name="file_path">/Users/drewhartsfield/Desktop/Loc/DEBUG_RLS_AUTH.md
