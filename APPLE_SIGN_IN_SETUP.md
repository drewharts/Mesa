# Sign in with Apple Setup Guide

## Issues Fixed

I've already made the following changes to fix the Sign in with Apple configuration:

1. ✅ **Added Apple Sign-In capability to entitlements** (`loc/loc.entitlements`)
2. ✅ **Added Apple authentication URL scheme** (`loc/Info.plist`)
3. ✅ **Added Apple URL handling in AppDelegate** (`loc/locApp.swift`)

## Required Apple Developer Account Setup

The errors you're seeing are likely due to missing Apple Developer account configuration. Follow these steps:

### 1. Apple Developer Account Configuration

1. **Log into Apple Developer Portal** (https://developer.apple.com)
2. **Go to Certificates, Identifiers & Profiles**
3. **Select "Identifiers" from the left sidebar**
4. **Find your app identifier** (`drewharts.loc`) or create it if it doesn't exist
5. **Click on the identifier to edit it**
6. **Scroll down to "Sign in with Apple"**
7. **Check the box to enable "Sign in with Apple"**
8. **Click "Configure" next to Sign in with Apple**
9. **Select "Enable as a primary App ID"**
10. **Click "Save"**

### 2. Xcode Project Configuration

1. **Open your project in Xcode**
2. **Select your project in the navigator**
3. **Select your main app target**
4. **Go to "Signing & Capabilities" tab**
5. **Click the "+" button to add a capability**
6. **Search for and add "Sign in with Apple"**
7. **Ensure your Team is selected**
8. **Verify the Bundle Identifier matches** (`drewharts.loc`)

### 3. Provisioning Profile

1. **In Xcode, go to "Signing & Capabilities"**
2. **Make sure "Automatically manage signing" is checked**
3. **Select your Team**
4. **Xcode should automatically create/update the provisioning profile**

### 4. Firebase Configuration

1. **Go to Firebase Console** (https://console.firebase.google.com)
2. **Select your project**
3. **Go to Authentication > Sign-in method**
4. **Enable "Apple" provider**
5. **Add your Apple Service ID** (if you have one, otherwise leave blank for development)
6. **Save the configuration**

### 5. Testing

1. **Clean and rebuild your project** (Product > Clean Build Folder)
2. **Run on a physical device** (Sign in with Apple doesn't work in simulator)
3. **Test the Sign in with Apple button**

## Common Issues and Solutions

### Error: "Authorization failed: Error Domain=AKAuthenticationError Code=-7026"

**Cause**: Missing or incorrect Apple Developer account configuration
**Solution**: Follow steps 1-3 above to properly configure your Apple Developer account

### Error: "process may not map database"

**Cause**: Simulator limitation or permission issues
**Solution**: Test on a physical device instead of simulator

### Error: "ASAuthorizationController credential request failed"

**Cause**: Missing URL scheme or entitlements
**Solution**: Verify the changes I made to `Info.plist` and `loc.entitlements`

## Verification Checklist

- [ ] Apple Developer account has Sign in with Apple enabled for `drewharts.loc`
- [ ] Xcode project has Sign in with Apple capability added
- [ ] Bundle identifier matches exactly: `drewharts.loc`
- [ ] Testing on physical device (not simulator)
- [ ] Firebase has Apple provider enabled
- [ ] Clean build and fresh install

## Additional Notes

- **Simulator Limitation**: Sign in with Apple doesn't work in iOS Simulator. You must test on a physical device.
- **Bundle ID Consistency**: Ensure your bundle identifier is exactly `drewharts.loc` everywhere.
- **Team Selection**: Make sure you're using the correct Apple Developer Team in Xcode.
- **Provisioning**: Let Xcode automatically manage signing to avoid provisioning profile issues.

## If Issues Persist

If you continue to see errors after following these steps:

1. **Check Apple Developer account status** - ensure your account is active
2. **Verify app identifier configuration** - double-check the Sign in with Apple settings
3. **Try a different device** - some devices may have cached authentication states
4. **Reset device settings** - go to Settings > General > Reset > Reset All Settings (this will clear cached authentication data)

The configuration changes I made should resolve the technical issues, but the Apple Developer account setup is required for the authentication to work properly.
