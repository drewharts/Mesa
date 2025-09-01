# Apple Sign In Debugging Guide

## Issues Fixed

I've made several improvements to fix the Sign in with Apple and App Group issues:

### ✅ **App Group Error Fixed**
- **Removed App Group dependency** from UserDefaults access
- **Eliminated the CFPrefsPlistSource error** by using only regular UserDefaults
- **Simplified TikTok sharing** to work without App Group configuration

### ✅ **Apple Sign In Improvements**
- **Added comprehensive debugging** to track the entire authentication flow
- **Fixed UserSession state management** with proper `@MainActor` handling
- **Added `setUserLoggedIn()` method** to ensure consistent login state updates
- **Enhanced error handling** throughout the authentication process

## Testing Steps

### 1. Clean Build
```bash
# In Xcode:
# 1. Product > Clean Build Folder
# 2. Product > Build
```

### 2. Run on Physical Device
- **Important**: Sign in with Apple doesn't work in iOS Simulator
- **Use a real iPhone/iPad** for testing

### 3. Check Console Logs
Look for these debug messages in Xcode console:

#### Expected Flow:
```
🍎 Preparing Apple Sign In request...
🍎 Apple Sign In request prepared with nonce
🍎 Apple Sign In result received
✅ Apple Sign In successful, processing credential...
🍎 Got Apple ID token, creating Firebase credential...
🔥 Signing in with Firebase...
✅ Firebase sign in successful!
👤 Firebase user UID: [some-uid]
👤 Fetching Apple user profile...
👤 User UID: [some-uid]
✅ User already exists in database
🔐 Setting user as logged in: [some-uid]
✅ User session updated - isUserLoggedIn: true, currentUserId: [some-uid]
📱 Registering FCM token for user: [some-uid]
🎉 User successfully logged in!
```

#### Or for New Users:
```
👤 User not found, creating new profile...
💾 Saving new user profile...
✅ Profile saved successfully!
🔐 Setting user as logged in: [some-uid]
✅ User session updated - isUserLoggedIn: true, currentUserId: [some-uid]
🎉 New user successfully logged in!
```

### 4. Common Issues & Solutions

#### Issue: "Authorization failed: Error Domain=AKAuthenticationError Code=-7026"
**Solution**: Follow the Apple Developer account setup in `APPLE_SIGN_IN_SETUP.md`

#### Issue: No console logs appear
**Solution**: 
- Check that you're testing on a physical device
- Ensure Apple Sign In capability is added in Xcode
- Verify bundle identifier matches exactly: `drewharts.loc`

#### Issue: User not being logged in after successful authentication
**Solution**: 
- Check console logs for the complete flow
- Verify `userSession.isUserLoggedIn` is being set to `true`
- Ensure `ContentView` is properly observing the UserSession

#### Issue: App Group error still appears
**Solution**: 
- The error should be eliminated with the latest changes
- If it persists, check that you're using the latest code
- Ensure no other parts of the app are accessing App Groups

## Debugging Checklist

- [ ] Testing on physical device (not simulator)
- [ ] Apple Developer account has Sign in with Apple enabled
- [ ] Xcode project has Sign in with Apple capability
- [ ] Bundle identifier is exactly `drewharts.loc`
- [ ] Firebase has Apple provider enabled
- [ ] Console shows the complete authentication flow
- [ ] UserSession state is properly updated
- [ ] App transitions from LoginView to MainView

## Expected Behavior

1. **Tap Apple Sign In button** → Should show Apple authentication sheet
2. **Complete Apple authentication** → Should show success in console
3. **Firebase authentication** → Should complete successfully
4. **User profile check/creation** → Should handle existing or new users
5. **UserSession update** → Should set `isUserLoggedIn = true`
6. **UI transition** → Should switch from LoginView to MainView

## If Issues Persist

1. **Check Firebase Console** - Verify Apple provider is enabled
2. **Check Apple Developer Portal** - Ensure Sign in with Apple is configured
3. **Test with Google Sign In** - Verify the authentication flow works with Google
4. **Check UserSession state** - Add breakpoints to verify state changes
5. **Verify ContentView logic** - Ensure it properly responds to `isUserLoggedIn` changes

The latest changes should resolve both the App Group error and the Apple Sign In authentication issues. The comprehensive debugging will help identify exactly where any remaining problems occur.
