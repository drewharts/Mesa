# Debug TikTok Authentication

## Step-by-Step Testing Guide

### 1. Enable Debug Logging

Add this to `TikTokAuthService.swift` temporarily:

```swift
init() {
    print("🔍 TikTokAuthService: Initializing...")
    Task {
        print("🔍 TikTokAuthService: Checking initial connection status...")
        await checkConnectionStatus()
    }
}

@MainActor
func checkConnectionStatus() async {
    print("🔍 TikTokAuthService: checkConnectionStatus called")
    isCheckingStatus = true
    defer { 
        isCheckingStatus = false 
        print("🔍 TikTokAuthService: Finished checking. Connected: \(isConnected)")
    }
    
    guard let user = Auth.auth().currentUser else {
        print("❌ TikTokAuthService: No Firebase user")
        isConnected = false
        return
    }
    
    guard let token = try? await user.getIDToken() else {
        print("❌ TikTokAuthService: Failed to get Firebase token")
        isConnected = false
        return
    }
    
    print("✅ TikTokAuthService: Got Firebase token")
    
    // ... rest of the function
}

func connectTikTok() {
    print("🔍 TikTokAuthService: connectTikTok called")
    guard let url = URL(string: "\(baseURL)/auth/tiktok/login") else { 
        print("❌ TikTokAuthService: Invalid URL")
        return 
    }
    
    print("🔍 TikTokAuthService: Opening URL: \(url)")
    UIApplication.shared.open(url)
}
```

### 2. Test Button Visibility

Add debug info to `TikTokConnectionButton.swift`:

```swift
var body: some View {
    VStack(spacing: 8) {
        // Debug info
        Text("Debug: isChecking=\(tikTokAuthService.isCheckingStatus), isConnected=\(tikTokAuthService.isConnected)")
            .font(.caption2)
            .foregroundColor(.red)
        
        // ... rest of the view
    }
}
```

### 3. Manual Testing Steps

1. **Launch the app**
   - Open Xcode console to see debug logs
   - Log in to the app

2. **Navigate to Profile**
   - You should see the TikTok button
   - Check console for initialization logs

3. **Test Connection Flow**
   - Tap "Connect TikTok" button
   - Should open Safari to TikTok OAuth page
   - Log in to TikTok (use a test account)
   - Authorize the app
   - Should redirect back to Mesa

4. **Verify Connection**
   - Return to app
   - Pull down to refresh the profile
   - Button should now show "TikTok Connected"

5. **Test Disconnection**
   - Tap the connected button
   - Confirm disconnect
   - Button should return to "Connect TikTok"

### 4. Common Issues to Check

1. **Button not visible?**
   ```swift
   // In ProfileView.swift, add:
   .onAppear {
       print("ProfileView appeared")
       print("TikTokAuthService exists: \(tikTokAuthService != nil)")
   }
   ```

2. **OAuth not working?**
   - Check Safari opens
   - Verify redirect URL matches backend config
   - Check for deep link handling in AppDelegate

3. **Status not updating?**
   - Force refresh: Pull down on profile
   - Check network logs in console
   - Verify backend returns correct status

### 5. Backend Testing with Postman/Insomnia

Create these requests:

1. **Get Status**
   - GET `https://mesa-backend-production.up.railway.app/auth/tiktok/status`
   - Header: `Authorization: Bearer YOUR_FIREBASE_TOKEN`

2. **Test Login Redirect**
   - GET `https://mesa-backend-production.up.railway.app/auth/tiktok/login`
   - Header: `Authorization: Bearer YOUR_FIREBASE_TOKEN`
   - Should return 302 redirect

3. **Test Disconnect**
   - DELETE `https://mesa-backend-production.up.railway.app/auth/tiktok/disconnect`
   - Header: `Authorization: Bearer YOUR_FIREBASE_TOKEN`

### 6. Deep Link Testing

Test the callback URL handling:

```bash
# In simulator, test deep link
xcrun simctl openurl booted "loc://auth/tiktok/callback?success=true"
```

### 7. Monitor Network Traffic

Use Charles Proxy or similar to see:
- Exact requests being made
- Response codes and data
- OAuth redirect flow

### 8. Backend Logs

Ask your backend developer to check:
- Redis for OAuth state storage
- Database for TikTok token storage
- Server logs for any errors

## Quick Checklist

- [ ] Firebase user is logged in
- [ ] TikTokAuthService is initialized
- [ ] Button appears on profile
- [ ] Tapping button opens Safari
- [ ] OAuth flow completes
- [ ] Status updates after auth
- [ ] Disconnect works
- [ ] Process URL with auth works