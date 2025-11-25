# 🔑 **Supabase User ID Architecture**

## **YES! The user IDs MUST match.**

### **How Supabase User IDs Work:**

#### **1. Authentication User ID (`auth.users.id`)**
- **Created by:** Supabase Auth when user signs in
- **Format:** UUID (e.g., `7E996518-30EC-48CB-A6B1-BF5A51A7D88B`)
- **Source:** `session.user.id.uuidString` in your code
- **Function:** `auth.uid()` in SQL policies

#### **2. Profile User ID (`users.id`)**
- **Should be:** Same UUID as auth user
- **Purpose:** Link profile data to authenticated user
- **Relationship:** 1:1 with `auth.users`

### **Why They Must Match:**

#### **RLS Policies Depend On This:**
```sql
-- This policy ONLY works if users.id = auth.users.id
CREATE POLICY users_insert_policy ON users
    FOR INSERT
    WITH CHECK (auth.uid()::text = id::text);
```

#### **Your Code Assumes This:**
```swift
// LoginViewModel - uses auth user's ID
let supabaseUserId = session.user.id.uuidString  // ← Auth ID

// UserService - saves to users table with same ID
profileData.id = supabaseUserId  // ← Same ID
```

### **What Happens When They Match:**

✅ **Authentication:** User signs in → `auth.users` record created  
✅ **Profile Lookup:** Query `users` table with `auth.uid()`  
✅ **Profile Creation:** Insert into `users` with matching ID  
✅ **RLS Security:** Policies allow access to own data only  

### **What Happens When They Don't Match:**

❌ **RLS Blocks Access:** `auth.uid() != users.id`  
❌ **Profile Creation Fails:** INSERT policy violation  
❌ **Data Isolation Broken:** Users could access others' data  

### **In Your Case:**

**Auth User ID:** `7E996518-30EC-48CB-A6B1-BF5A51A7D88B`  
**Users Table ID:** Should also be `7E996518-30EC-48CB-A6B1-BF5A51A7D88B`

### **Verification Query:**

```sql
-- Check if user exists in both tables
SELECT
    au.id as auth_id,
    au.email as auth_email,
    u.id as profile_id,
    u.first_name,
    u.last_name
FROM auth.users au
LEFT JOIN public.users u ON au.id::text = u.id::text
WHERE au.id = '7E996518-30EC-48CB-A6B1-BF5A51A7D88B';
```

### **Your Current Issue:**

The user **does exist** in `auth.users` (sign-in works), but **doesn't exist** in `users` table, and RLS is preventing the creation.

### **Solution:**

1. **Verify IDs match** in your code
2. **Temporarily disable RLS** to create the missing profile
3. **Fix RLS policies** to allow proper access

### **Code Check:**

In `LoginViewModel.authenticateWithSupabase`:

```swift
// ✅ CORRECT: Uses auth user ID
let supabaseUserId = session.user.id.uuidString

// ✅ CORRECT: Passes same ID to profile creation
await fetchOrCreateGoogleProfile(user: user, supabaseUserId: supabaseUserId)
```

In `UserService.saveUserProfile`:

```swift
// ✅ CORRECT: Uses the auth user ID
profileData.id = uid  // uid comes from supabaseUserId
```

**Yes, the IDs should absolutely match!** This is the foundation of Supabase's security model.</contents>
</xai:function_call<parameter name="file_path">/Users/drewhartsfield/Desktop/Loc/USER_ID_EXPLANATION.md
