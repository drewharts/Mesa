# 🔄 **Authentication Data Migration Solution**

## **You've Identified the Root Cause!**

You're absolutely right. The issue is:

### **The Problem:**
1. ✅ **Firebase users exist** in your `users` table with Firebase UIDs
2. ❌ **Supabase auth is empty** - no corresponding auth.users records
3. ❌ **New Supabase sign-ins** create NEW auth users with NEW UUIDs
4. ❌ **ID mismatch** - Firebase UID ≠ Supabase auth UID
5. ❌ **RLS blocks creation** because `auth.uid()` doesn't match existing user IDs

### **The Solution: Auth User Migration**

You need to migrate your authentication data so that Supabase auth users have the same identities as your Firebase users.

## **Option 1: Update Existing User Records (Recommended)**

### **Step 1: Export Firebase User Data**
If you still have Firebase access, export the user data:
```javascript
// Firebase Admin SDK
const users = await admin.auth().listUsers();
users.users.forEach(user => {
  console.log(user.uid, user.email, user.displayName);
});
```

### **Step 2: Create Supabase Auth Users**
Use Supabase Admin API to create users with same emails:

```javascript
// Use Supabase Admin API
const { createClient } = require('@supabase/supabase-js');
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

// Create user with same email
const { data, error } = await supabase.auth.admin.createUser({
  email: 'user@example.com',
  password: 'temporary_password', // Users will reset via email
  user_metadata: {
    firebase_uid: 'firebase_user_id_here',
    migrated_from: 'firebase'
  }
});
```

### **Step 3: Update Your Users Table**
Map the old Firebase UIDs to new Supabase UIDs:

```sql
-- Add a column to track Firebase UIDs
ALTER TABLE users ADD COLUMN firebase_uid TEXT;

-- Update existing records with Firebase UIDs
UPDATE users SET firebase_uid = id WHERE firebase_uid IS NULL;

-- Update user IDs to match new Supabase auth UIDs
-- (You'll need to map them based on email or other identifiers)
UPDATE users
SET id = 'new_supabase_auth_uid_here'
WHERE email = 'user@example.com';
```

## **Option 2: User Matching on Sign-In (Alternative)**

### **Modify LoginViewModel to Handle Migration:**

```swift
private func authenticateWithSupabase(
    idToken: String,
    user: GIDGoogleUser,
    userSession: UserSession
) async {
    do {
        let session = try await authService.signInWithIdToken(
            provider: .google,
            idToken: idToken
        )
        
        let supabaseUserId = session.user.id.uuidString
        
        // Check if we have an existing user with this email
        await findAndLinkExistingUser(
            email: user.profile?.email,
            supabaseUserId: supabaseUserId,
            userSession: userSession
        )
        
    } catch {
        print("❌ Supabase auth error: \(error)")
    }
}

private func findAndLinkExistingUser(
    email: String?,
    supabaseUserId: String,
    userSession: UserSession
) async {
    guard let email = email else { return }
    
    // Search for existing user by email
    userService.findUserByEmail(email) { [weak self] existingUser in
        if let existingUser = existingUser {
            // Found existing user - update their ID to match Supabase auth
            self?.migrateUserToSupabaseAuth(
                existingUserId: existingUser.id,
                newSupabaseId: supabaseUserId,
                userSession: userSession
            )
        } else {
            // No existing user - create new profile
            self?.createNewUserProfile(
                supabaseUserId: supabaseUserId,
                email: email,
                userSession: userSession
            )
        }
    }
}
```

### **Add Migration Methods to UserService:**

```swift
func findUserByEmail(_ email: String, completion: @escaping (ProfileData?) -> Void) {
    Task { @MainActor in
        do {
            let profiles: [ProfileData] = try await SupabaseManager.shared.database
                .from("users")
                .select()
                .eq("email", value: email)
                .execute()
                .value
            
            completion(profiles.first)
        } catch {
            completion(nil)
        }
    }
}

func migrateUserId(oldId: String, newId: String, completion: @escaping (Error?) -> Void) {
    // Update all related tables to use new Supabase auth ID
    // This is complex - involves updating favorites, reviews, etc.
    print("⚠️ User ID migration not implemented yet")
    completion(NSError(domain: "Migration", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not implemented"]))
}
```

## **Option 3: Start Fresh (Simplest)**

If your user base is small, consider starting fresh:

1. **Clear existing users table** (backup first!)
2. **Let users re-sign up** with Supabase auth
3. **New profiles will be created** with correct Supabase auth IDs

```sql
-- Backup existing data
CREATE TABLE users_backup AS SELECT * FROM users;

-- Clear users table
DELETE FROM users;

-- Now new sign-ins will create profiles with correct Supabase auth IDs
```

## **Recommended Approach:**

**For most apps:** Use **Option 1** (proper migration) if you have user data to preserve.

**For testing/small apps:** Use **Option 3** (start fresh) to get working quickly.

**For complex scenarios:** Use **Option 2** (sign-in time migration) as a bridge.

## **Immediate Fix:**

Since you're testing, try **Option 3** first - clear the users table and let the current sign-in create a fresh profile with the correct Supabase auth ID.

```sql
-- Quick fix for testing
DELETE FROM users WHERE email = 'drewharts8@gmail.com';
```

Then sign in again - it should create a profile with the correct Supabase auth ID!

**Which approach do you want to implement?** 🎯</contents>
</xai:function_call<parameter name="file_path">/Users/drewhartsfield/Desktop/Loc/AUTH_MIGRATION_SOLUTION.md
