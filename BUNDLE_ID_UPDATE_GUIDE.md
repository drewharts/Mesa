# Bundle ID Update Guide

## ✅ What I've Fixed

I've updated your project's Bundle ID from `drewharts.loc` to `drewharts.locc` to match your Firebase configuration. Here's what was changed:

### Updated Bundle IDs:
- **Main App**: `drewharts.loc` → `drewharts.locc`
- **Tests**: `drewharts.locTests` → `drewharts.loccTests`
- **UI Tests**: `drewharts.locUITests` → `drewharts.loccUITests`
- **Share Extension**: `drewharts.loc.Mesa-Share` → `drewharts.locc.Mesa-Share`
- **Apple Sign In URL Scheme**: `drewharts.loc` → `drewharts.locc`

## 🔧 Next Steps Required

### 1. Update Apple Developer Account

You need to update your Apple Developer account to use the new Bundle ID:

1. **Go to Apple Developer Portal** → https://developer.apple.com
2. **Certificates, Identifiers & Profiles**
3. **Select "Identifiers"**
4. **Find your app identifier** (currently `drewharts.loc`)
5. **Click on it to edit**
6. **Change the Bundle ID** from `drewharts.loc` to `drewharts.locc`
7. **Click "Save"**

### 2. Update Xcode Project Settings

1. **Open Xcode**
2. **Select your project** in the navigator
3. **Select each target** and verify the Bundle ID:
   - **Main App**: `drewharts.locc`
   - **Tests**: `drewharts.loccTests`
   - **UI Tests**: `drewharts.loccUITests`
   - **Share Extension**: `drewharts.locc.Mesa-Share`

### 3. Update Signing & Capabilities

1. **For each target**, go to "Signing & Capabilities"
2. **Ensure "Automatically manage signing"** is checked
3. **Select your Team**
4. **Xcode should automatically update** the provisioning profiles

### 4. Clean and Rebuild

1. **Product** → **Clean Build Folder**
2. **Product** → **Build**

## 🧪 Testing

After completing the updates:

1. **Run on a physical device** (not simulator)
2. **Test Apple Sign In**
3. **Check console logs** - you should see:
   ```
   ✅ Firebase sign in successful!
   👤 Firebase user UID: [some-uid]
   👤 Fetching Apple user profile...
   🔐 Setting user as logged in: [some-uid]
   🎉 User successfully logged in!
   ```

## Expected Result

The error should be resolved:
```
❌ Firebase sign in failed: The audience in ID Token [drewharts.loc] does not match the expected audience drewharts.locc.
```

Should become:
```
✅ Firebase sign in successful!
```

## ⚠️ Important Notes

- **Don't forget to update Apple Developer account** - this is crucial
- **Test on physical device** - Apple Sign In doesn't work in simulator
- **Clean build** after making changes
- **Check that all targets** have the correct Bundle ID

## If Issues Persist

1. **Verify Apple Developer account** has the new Bundle ID
2. **Check Firebase Console** - ensure Apple provider is enabled
3. **Verify all Bundle IDs** in Xcode match exactly
4. **Clean and rebuild** the project

The Bundle ID mismatch was the root cause of the authentication failure. Once you update the Apple Developer account, Apple Sign In should work perfectly! 🎉
