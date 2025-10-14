# 🔍 **Check if User Profile Already Exists**

## **Your Situation:**
You say the user profile already exists, but the code is still trying to create it. Let's verify!

## **Step 1: Check if Profile Exists in Database**

Run this in Supabase SQL Editor:

```sql
-- Check if the user profile exists
SELECT id, first_name, last_name, email, created_at
FROM users
WHERE id = '7E996518-30EC-48CB-A6B1-BF5A51A7D88B';

-- Also check by email
SELECT id, first_name, last_name, email
FROM users
WHERE email = 'drewharts8@gmail.com';
```

**If the profile exists:** The issue is the query logic - it should find the profile and not try to create it.

**If the profile doesn't exist:** The issue is RLS blocking the legitimate creation.

## **Step 2: Test RLS Bypass**

If the profile doesn't exist, temporarily bypass RLS:

```sql
-- Temporarily disable RLS
ALTER TABLE users DISABLE ROW LEVEL SECURITY;

-- Try to create the profile manually
INSERT INTO users (
    id,
    first_name,
    last_name,
    email,
    full_name,
    full_name_lower,
    created_at
) VALUES (
    '7E996518-30EC-48CB-A6B1-BF5A51A7D88B',
    'Andrew',
    'Hartsfield II',
    'drewharts8@gmail.com',
    'Andrew Hartsfield II',
    'andrew hartsfield ii',
    NOW()
);

-- Re-enable RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
```

## **Step 3: Debug the Query Logic**

If the profile does exist, the issue is in your `UserService.fetchUserById` method. Add debug logging:

```swift
func fetchUserById(userId: String, completion: @escaping (Result<ProfileData, Error>) -> Void) {
    print("🔍 DEBUG: Looking for user profile with ID: \(userId)")

    Task { @MainActor in
        do {
            // First check if user exists without RLS
            let count = try await SupabaseManager.shared.database
                .from("users")
                .select("*", count: .exact)
                .eq("id", value: userId)
                .execute()

            print("🔍 DEBUG: Found \(count.count) profiles with this ID")

            if count.count > 0 {
                // Now fetch the actual profile
                let response: [ProfileData] = try await SupabaseManager.shared.database
                    .from("users")
                    .select()
                    .eq("id", value: userId)
                    .execute()
                    .value

                if let profileData = response.first {
                    print("✅ DEBUG: Successfully found profile: \(profileData.firstName)")
                    completion(.success(profileData))
                } else {
                    print("❌ DEBUG: Count > 0 but no profile returned")
                    let notFoundError = NSError(domain: "UserService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Profile count mismatch"])
                    completion(.failure(notFoundError))
                }
            } else {
                print("ℹ️ DEBUG: No profile found, should create new one")
                let notFoundError = NSError(domain: "UserService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User profile not found"])
                completion(.failure(notFoundError))
            }
        } catch {
            print("❌ DEBUG: Query error: \(error.localizedDescription)")
            completion(.failure(error))
        }
    }
}
```

## **Understanding Your Email Uniqueness Requirement**

You want:
- ✅ **Multiple users** can have the same name
- ❌ **No duplicate emails** (enforced by `unique(email)` constraint)

Your schema already handles this correctly:
```sql
constraint users_email_key unique (email)  -- ✅ Prevents duplicate emails
-- No unique constraint on names     -- ✅ Allows duplicate names
```

## **The Real Issue**

**If profile exists:** Your query logic has a bug  
**If profile doesn't exist:** RLS policy is incorrectly blocking the insert

## **Quick Test:**

1. **Check if profile exists** (SQL query above)
2. **If it exists:** The query logic is broken
3. **If it doesn't exist:** RLS policy needs fixing

**Run the SQL check first** - that will tell us exactly what's happening! 🔍</contents>
</xai:function_call<parameter name="file_path">/Users/drewhartsfield/Desktop/Loc/CHECK_USER_EXISTS.md
