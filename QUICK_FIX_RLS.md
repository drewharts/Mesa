# 🚀 **Quick Fix: Disable RLS Temporarily**

## **Immediate Solution**

Since the user already exists in Supabase auth but profile creation fails due to RLS, let's temporarily disable RLS so you can test the full authentication flow.

## **Step 1: Disable RLS on Users Table**

Run this in your Supabase SQL Editor:

```sql
-- Temporarily disable RLS to test profile creation
ALTER TABLE users DISABLE ROW LEVEL SECURITY;
```

## **Step 2: Test Authentication**

1. **Run your app**
2. **Sign in with Google** (using the existing user)
3. **Expected result**: Profile should be created successfully

**Console should show:**
```
✅ Signed in with Google via Supabase
🔄 [UserService] Fetching user profile from Supabase: 7E996518-30EC-48CB-A6B1-BF5A51A7D88B
ℹ️ [UserService] User profile not found (404): ...
👤 Creating new user profile...
💾 [UserService] Saving user profile to Supabase: Andrew Hartsfield II
✅ [UserService] Successfully saved user profile to Supabase
🎉 User successfully logged in!
```

## **Step 3: Verify Profile Created**

Check your Supabase dashboard:
- **Table Editor** → **users**
- You should see a row with ID: `7E996518-30EC-48CB-A6B1-BF5A51A7D88B`

## **Step 4: Re-enable RLS**

Once you confirm profile creation works:

```sql
-- Re-enable RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
```

## **Step 5: Debug RLS Policies**

If profile creation fails again after re-enabling RLS, the issue is with your RLS policy configuration. Check:

```sql
-- Verify RLS is enabled
SELECT tablename, rowsecurity FROM pg_tables WHERE tablename = 'users';

-- Check policies exist
SELECT policyname FROM pg_policies WHERE tablename = 'users';
```

You should see:
- `rowsecurity = true`
- Policies: `users_select_policy`, `users_insert_policy`, `users_update_policy`

## **Why This Happens**

The user exists in Supabase's `auth.users` table (authentication works), but your custom `users` table has RLS policies that prevent the insert operation. This is common when:

1. RLS policies aren't configured correctly
2. Auth context (`auth.uid()`) doesn't match the user ID
3. Policies reference wrong column names

## **Long-term Fix**

Once you confirm this works, we need to fix your RLS policies. The issue is likely in the policy conditions:

```sql
-- Current (may be wrong)
WITH CHECK (auth.uid()::text = id::text)

-- Alternative (try this if above doesn't work)
WITH CHECK (auth.uid()::text = id)
```

**Try the temporary disable first - it should immediately fix your authentication flow!** 🎉
