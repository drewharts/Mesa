# TikTok Import - Fixed Instructions

## How It Works Now

The TikTok import now works through UserDefaults sharing between the share extension and main app:

1. **Share Extension** stores the TikTok URL in shared UserDefaults (`group.com.drewhartsfield.loc`)
2. **Main App** checks for pending URLs when:
   - App launches (`.task` modifier)
   - App becomes active (`didBecomeActiveNotification`)
   - App enters foreground (`willEnterForegroundNotification`)
   - Multiple times with delays (1 second, 2 seconds after launch)

## Key Changes Made

### 1. Removed URL Opening from Share Extension
- Share extensions can't reliably open custom URL schemes
- Now just stores the URL and completes immediately
- Main app will process when it next becomes active

### 2. App Group Configuration
- Using `group.com.drewhartsfield.loc` throughout
- Make sure BOTH targets have this app group enabled in Xcode

### 3. Multiple Check Points
The app now checks for pending TikTok URLs:
- On app launch
- When app becomes active (switching back from share sheet)
- When app enters foreground
- With delays to catch any timing issues

## Xcode Setup Required

### 1. Main App Target
1. Select the main app target in Xcode
2. Go to Signing & Capabilities
3. Add "App Groups" capability if not present
4. Enable `group.com.drewhartsfield.loc`

### 2. ShareExtension Target
1. Select the ShareExtension target
2. Go to Signing & Capabilities
3. Add "App Groups" capability if not present
4. Enable `group.com.drewhartsfield.loc`

### 3. Clean and Rebuild
1. Product → Clean Build Folder (⇧⌘K)
2. Delete app from device/simulator
3. Rebuild and install fresh

## Testing

### Test with Debug Button
1. Open the app
2. Tap the red hammer button
3. Should see: "✅ Can access app group: group.com.drewhartsfield.loc"

### Test Share Extension
1. Open TikTok
2. Find a video with location
3. Share → Mesa
4. The share sheet will close immediately
5. Switch back to Mesa app
6. Within 1-2 seconds, the TikTok should be processed

### Expected Flow
1. Share extension logs:
   ```
   🎵🎵🎵 SHAREEXTENSION: HANDLING TIKTOK URL! 🎵🎵🎵
   ✅ Stored TikTok URL in shared UserDefaults
   💾 ShareExtension: URL stored successfully
   ```

2. When you switch to Mesa app:
   ```
   📱📱📱 APP BECAME ACTIVE! 📱📱📱
   🔍🔍🔍 FORCE CHECKING FOR PENDING TIKTOK URLS! 🔍🔍🔍
   🎉🎉🎉 FOUND PENDING TIKTOK URL! 🎉🎉🎉
   ```

3. Processing:
   ```
   🌍🌍🌍 GLOBAL TIKTOK MONITOR TRIGGERED! 🌍🌍🌍
   🌐🌐🌐 TIKTOKSERVICE: PROCESS URL CALLED! 🌐🌐🌐
   ✅✅✅ TIKTOK URL PROCESSED SUCCESSFULLY! ✅✅✅
   ```

## Troubleshooting

### If URLs aren't being detected:
1. Check app group is enabled for BOTH targets
2. Use debug button to verify app group access
3. Check console for "❌ CRITICAL: Cannot access shared UserDefaults!"

### If processing fails:
1. Check network connection
2. Verify the TikTok has location information
3. Check TikTokService logs for API errors

## How the Flow Works

1. User shares TikTok video to Mesa
2. Share extension saves URL to shared UserDefaults
3. Share sheet closes
4. User returns to Mesa app (or opens it)
5. App detects it became active and checks for pending URLs
6. If found, posts notification to process the URL
7. TikTokService calls backend API
8. Place is created and displayed

The key insight is that we don't need to open the app from the share extension - we just need to detect when the app becomes active and check for any pending URLs!