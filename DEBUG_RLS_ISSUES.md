# 🔍 **Debugging RLS Issues**

## **Issues Identified:**

1. **"Cannot coerce the result to a single JSON object"** - Query issue
2. **"new row violates row-level security policy"** - RLS policy issue

## **Step 1: Check if RLS Policies Are Applied**

Run this in your Supabase SQL Editor:

```sql
-- Check if RLS is enabled on users table
SELECT schemaname, tablename, rowsecurity
FROM pg_tables
WHERE tablename = 'users';

-- List all policies on users table
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'users';
```

**Expected Results:**
- `rowsecurity` should be `true` for users table
- You should see policies: `users_select_policy`, `users_insert_policy`, `users_update_policy`

## **Step 2: Test Auth Context**

Add this debug code to your `UserService.fetchUserById`:

```swift
func fetchUserById(userId: String, completion: @escaping (Result<ProfileData, Error>) -> Void) {
    print("🔍 DEBUG: Fetching user profile for: \(userId)")
    print("🔍 DEBUG: Current auth session:", SupabaseManager.shared.auth.currentSession)

    // Test query without RLS first
    Task { @MainActor in
        do {
            let response = try await SupabaseManager.shared.database
                .from("users")
                .select("*")  // Select all columns for debugging
                .eq("id", value: userId)
                .execute()

            print("🔍 DEBUG: Raw response:", response)

            // Try without .single() first
            let profiles: [ProfileData] = try await SupabaseManager.shared.database
                .from("users")
                .select()
                .eq("id", value: userId)
                .execute()
                .value

            print("🔍 DEBUG: Found profiles count:", profiles.count)

            if let profileData = profiles.first {
                print("✅ Found profile:", profileData)
                completion(.success(profileData))
            } else {
                print("ℹ️ No profile found for user:", userId)
                let notFoundError = NSError(domain: "UserService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User profile not found"])
                completion(.failure(notFoundError))
            }
        } catch {
            print("❌ Error:", error.localizedDescription)
            completion(.failure(error))
        }
    }
}
```

## **Step 3: Test Insert Without RLS**

Temporarily disable RLS to test:

```sql
-- Temporarily disable RLS for testing
ALTER TABLE users DISABLE ROW LEVEL SECURITY;

-- Try to create a profile manually
INSERT INTO users (id, first_name, last_name, email, full_name, full_name_lower)
VALUES ('7E996518-30EC-48CB-A6B1-BF5A51A7D88B', 'Test', 'User', 'test@example.com', 'Test User', 'test user');

-- Re-enable RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
```

## **Step 4: Check Auth UID Function**

Test if `auth.uid()` works in your Supabase project:

```sql
-- Test auth.uid() function
SELECT auth.uid() as current_user_id;

-- Test with your specific user ID
SELECT '7E996518-30EC-48CB-A6B1-BF5A51A7D88B'::text = auth.uid()::text as id_matches;
```

## **Step 5: Alternative: Use Supabase Auth Users Table**

Instead of a separate `users` table, you could use Supabase's built-in `auth.users` table and add custom metadata:

```swift
// Update profile in auth.users metadata
try await SupabaseManager.shared.auth.updateUser(
    UserAttributes(data: [
        "first_name": "Andrew",
        "last_name": "Hartsfield II",
        "full_name": "Andrew Hartsfield II"
    ])
)

// Get profile from auth metadata
let user = SupabaseManager.shared.auth.currentUser
let firstName = user?.userMetadata["first_name"] as? String
```

## **Step 6: Fix RLS Policies (If Issues Found)**

If policies are missing, run:

```sql
-- Drop existing policies if they exist
DROP POLICY IF EXISTS users_select_policy ON users;
DROP POLICY IF EXISTS users_insert_policy ON users;
DROP POLICY IF EXISTS users_update_policy ON users;

-- Recreate policies
CREATE POLICY users_select_policy ON users FOR SELECT USING (true);
CREATE POLICY users_insert_policy ON users FOR INSERT WITH CHECK (auth.uid()::text = id);
CREATE POLICY users_update_policy ON users FOR UPDATE USING (auth.uid()::text = id);
```

## **Quick Test:**

1. **Disable RLS temporarily:**
   ```sql
   ALTER TABLE users DISABLE ROW LEVEL SECURITY;
   ```

2. **Try sign-in again** - should work without RLS errors

3. **Re-enable RLS:**
   ```sql
   ALTER TABLE users ENABLE ROW LEVEL SECURITY;
   ```

If it works with RLS disabled, the issue is with your RLS policy configuration.

## **Most Likely Fix:**

The issue is probably that your RLS policies aren't applied correctly, or there's an issue with the `auth.uid()` function in your Supabase project context.

**Try Step 1 first** - check if your policies are actually applied in the database!
