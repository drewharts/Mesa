# 🔐 **Supabase Authentication Migration Guide**

## **Overview**

Converting Firebase Authentication (Google & Apple Sign-In) to Supabase Authentication.

---

## **Step 1: Configure Supabase Dashboard**

### **1.1 Enable Google OAuth**

1. Go to your Supabase Dashboard
2. Navigate to **Authentication → Providers**
3. Enable **Google** provider
4. Add your **Google OAuth Client ID** and **Client Secret**:
   - Get these from [Google Cloud Console](https://console.cloud.google.com/)
   - Create OAuth 2.0 credentials
   - Add redirect URI: `https://your-project.supabase.co/auth/v1/callback`

### **1.2 Enable Apple Sign-In**

1. In Supabase Dashboard → **Authentication → Providers**
2. Enable **Apple** provider
3. Configure Apple Sign-In:
   - **Services ID**: Your Apple Services ID
   - **Team ID**: Your Apple Developer Team ID
   - **Key ID**: Your Apple Sign-In Key ID
   - **Private Key**: Your Apple Sign-In private key (.p8 file)

### **1.3 Google OAuth Setup**

For your existing Google OAuth to work with Supabase:

```swift
// You'll need to get the client ID from Supabase Dashboard
// Under Authentication → Providers → Google → Configuration
let supabaseGoogleClientId = "YOUR_SUPABASE_GOOGLE_CLIENT_ID"
```

**Note**: You can keep your existing Firebase Google OAuth client ID or create a new one in Supabase.

---

## **Step 2: Update iOS Configuration**

### **2.1 Info.plist Updates**

Add Supabase redirect URL scheme:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <!-- Keep your existing Google Sign-In URL -->
            <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
            <!-- Add Supabase deep link -->
            <string>com.yourdomain.yourapp</string>
        </array>
    </dict>
</array>
```

---

## **Step 3: Authentication Flow**

### **3.1 Google Sign-In Flow**

**Old (Firebase)**:
1. User taps "Sign in with Google"
2. Google Sign-In SDK presents UI
3. Get Google ID token
4. Exchange token with Firebase Auth
5. Firebase creates/signs in user

**New (Supabase)**:
1. User taps "Sign in with Google"
2. Google Sign-In SDK presents UI
3. Get Google ID token
4. Send token to Supabase Auth
5. Supabase creates/signs in user
6. Supabase returns session with JWT

### **3.2 Apple Sign-In Flow**

**Old (Firebase)**:
1. User taps "Sign in with Apple"
2. Apple Sign-In presents UI
3. Get Apple ID token
4. Exchange token with Firebase Auth
5. Firebase creates/signs in user

**New (Supabase)**:
1. User taps "Sign in with Apple"
2. Apple Sign-In presents UI
3. Get Apple ID token + nonce
4. Send token to Supabase Auth
5. Supabase creates/signs in user
6. Supabase returns session with JWT

---

## **Step 4: User Profile Management**

### **4.1 Profile Data in Supabase**

Supabase stores user authentication data in `auth.users` table. Your custom profile data goes in your `public.users` table:

```sql
-- Your existing users table
CREATE TABLE public.users (
    id UUID REFERENCES auth.users(id) PRIMARY KEY,
    first_name TEXT,
    last_name TEXT,
    email TEXT,
    profile_photo_url TEXT,
    phone_number TEXT,
    full_name_lower TEXT,
    full_name TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### **4.2 Profile Creation Flow**

1. User signs in with Google/Apple
2. Supabase creates auth user automatically
3. Check if profile exists in `public.users`
4. If not, create profile with data from OAuth provider
5. Link to auth user via `id` column

---

## **Step 5: Session Management**

### **5.1 Supabase Session Structure**

```swift
struct Session {
    let user: Auth.User           // User info
    let accessToken: String        // JWT for API calls
    let refreshToken: String       // Token to refresh session
    let expiresAt: Date           // When session expires
}
```

### **5.2 Session Storage**

Supabase automatically:
- Stores session in device keychain
- Refreshes expired tokens
- Handles logout/cleanup

---

## **Step 6: Security Considerations**

### **6.1 Remove Firebase Security Checks**

Your current code has extensive Firebase-specific security checks:
```swift
// Old Firebase security checks
let hasGoogleProvider = firebaseUser.providerData.contains { $0.providerID == "google.com" }
let hasAppleProvider = firebaseUser.providerData.contains { $0.providerID == "apple.com" }
```

**Supabase handles this automatically** through:
- Provider verification at auth level
- RLS policies preventing cross-provider data access
- JWT tokens tied to specific auth method

### **6.2 Account Linking Prevention**

Supabase prevents account linking by default. Users must use the same email/provider combination.

---

## **Step 7: Migration Checklist**

- [ ] Configure Google OAuth in Supabase Dashboard
- [ ] Configure Apple Sign-In in Supabase Dashboard
- [ ] Update `LoginViewModel` to use Supabase Auth
- [ ] Remove Firebase Auth imports
- [ ] Test Google Sign-In flow
- [ ] Test Apple Sign-In flow
- [ ] Test profile creation for new users
- [ ] Test existing user login
- [ ] Remove Firebase Auth dependency from Xcode project
- [ ] Update `UserSession` to use Supabase session

---

## **Benefits of Supabase Auth**

✅ **Simpler Code**: Less boilerplate, fewer security checks  
✅ **Better Security**: Built-in RLS, JWT tokens, automatic refresh  
✅ **Unified Backend**: Auth + Database in one place  
✅ **Better Developer Experience**: Clear error messages, better docs  
✅ **Cost Effective**: No separate Firebase Auth billing  

---

**Next**: I'll update your `LoginViewModel.swift` to use Supabase Auth!

