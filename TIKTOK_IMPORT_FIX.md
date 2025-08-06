# TikTok Import Fix Instructions

## Critical Issue Found
The app group identifier is mismatched between the app and share extension:
- **Entitlements**: `group.com.drewhartsfield.mesa`
- **Code (now fixed)**: Changed from `group.com.drewhartsfield.loc` to `group.com.drewhartsfield.mesa`

## Changes Made

### 1. Fixed App Group Identifier
Updated all references from `group.com.drewhartsfield.loc` to `group.com.drewhartsfield.mesa` in:
- `/ShareExtension/ShareViewController.swift`
- `/loc/locApp.swift`
- `/loc/Views/MainView.swift`
- `/loc/Views/SplashScreenView.swift`

### 2. Enhanced Share Extension
- Fixed the `openURL` method to use `extensionContext?.open()` instead of the UIApplication responder chain
- Added comprehensive logging throughout the flow
- Added synchronization and verification of UserDefaults storage

### 3. Added Multiple Check Points
- App launch check in `.task` modifier
- App became active check
- App will enter foreground check
- Multiple delayed checks (1 second, 2 seconds)
- Extended timeout from 30 seconds to 5 minutes

### 4. Enhanced Debug Button
The debug button (hammer icon) now:
- Verifies app group access
- Shows all stored keys
- Displays URL age
- Tests with dummy URL if no pending URL found

## Xcode Configuration Required

### 1. Share Extension Entitlements
The ShareExtension needs its own entitlements file with the app group:

1. In Xcode, select the ShareExtension target
2. Go to Signing & Capabilities
3. Add "App Groups" capability if not present
4. Enable `group.com.drewhartsfield.mesa`

### 2. Verify Main App Entitlements
1. Select the main app target
2. Go to Signing & Capabilities
3. Verify App Groups shows `group.com.drewhartsfield.mesa`

### 3. Clean Build
1. Product → Clean Build Folder (⇧⌘K)
2. Delete derived data: `~/Library/Developer/Xcode/DerivedData`
3. Rebuild the app

## Testing Steps

### Test 1: Debug Button
1. Open the app
2. Tap the red hammer button
3. Check console logs for:
   - "✅ Can access app group: group.com.drewhartsfield.mesa"
   - Notification posting confirmation

### Test 2: Share Extension
1. Open TikTok app
2. Find a video with location info
3. Share → More → Mesa
4. Check console logs for:
   - "🎵🎵🎵 SHAREEXTENSION: HANDLING TIKTOK URL!"
   - "✅ Stored TikTok URL in shared UserDefaults"
   - "✅✅✅ SUCCESSFULLY OPENED MAIN APP!"

### Test 3: Background Import
1. Share a TikTok video to Mesa
2. If app doesn't open automatically, open it manually
3. The app should detect and process the URL within 2 seconds

## Expected Console Output Flow

1. **Share Extension**:
   ```
   🎵🎵🎵 SHAREEXTENSION: HANDLING TIKTOK URL! 🎵🎵🎵
   ✅ Stored TikTok URL in shared UserDefaults
   ✅ Verified URL stored
   🔗 Created app URL: loc://share/tiktok?url=...
   ```

2. **Main App (if opened via URL)**:
   ```
   💫💫💫 SWIFTUI ONOPENURL CALLED! 💫💫💫
   🎵🎵🎵 handleSharedTikTokURL CALLED! 🎵🎵🎵
   📨 About to post ProcessSharedTikTok notification...
   ```

3. **Main App (if already open)**:
   ```
   📱📱📱 APP BECAME ACTIVE! 📱📱📱
   🔍🔍🔍 FORCE CHECKING FOR PENDING TIKTOK URLS! 🔍🔍🔍
   🎉🎉🎉 FOUND PENDING TIKTOK URL! 🎉🎉🎉
   ```

4. **Processing**:
   ```
   🌍🌍🌍 GLOBAL TIKTOK MONITOR TRIGGERED! 🌍🌍🌍
   🌐🌐🌐 TIKTOKSERVICE: PROCESS URL CALLED! 🌐🌐🌐
   ✅✅✅ TIKTOK URL PROCESSED SUCCESSFULLY! ✅✅✅
   ```

## If Still Not Working

1. **Check Provisioning Profiles**: Ensure both app and extension have proper provisioning profiles with app group capability
2. **Check Bundle IDs**: Verify the share extension bundle ID is `com.drewhartsfield.loc.ShareExtension`
3. **Check Console Logs**: Look for "❌❌❌ CANNOT ACCESS APP GROUP!" which indicates configuration issue
4. **Test Direct URL**: Try opening `loc://share/tiktok?url=https://www.tiktok.com/t/ZP8hk6G3s/` in Safari

## Key Improvements Made

1. **Fixed critical app group mismatch** - This was the main issue
2. **Added multiple fallback mechanisms** - URL checking on app resume/activate
3. **Extended timeouts** - From 30 seconds to 5 minutes
4. **Enhanced logging** - Every step is now logged for debugging
5. **Added verification** - Share extension verifies URL was stored
6. **Synchronous UserDefaults** - Force synchronize to ensure data is written