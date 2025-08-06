# Share Extension Setup Instructions

To complete the setup and make your app appear in the iOS share sheet when sharing from TikTok, follow these steps in Xcode:

## 1. Add Share Extension Target

1. Open `loc.xcodeproj` in Xcode
2. Select your project in the navigator
3. Click the "+" button at the bottom of the targets list
4. Choose "Share Extension" from the iOS templates
5. Name it "ShareExtension"
6. Set the bundle identifier to: `com.yourcompany.loc.ShareExtension` (replace with your actual bundle ID prefix)
7. Click "Finish"

## 2. Configure App Groups

Both your main app and the share extension need to be in the same app group to share data:

1. Select your main app target
2. Go to "Signing & Capabilities"
3. Click "+ Capability"
4. Add "App Groups"
5. Create a new app group: `group.com.yourcompany.loc`
6. Repeat the same steps for the ShareExtension target

## 3. Update the ShareExtension Info.plist

Replace the ShareExtension's Info.plist content with the one created in this folder, or update it to include the proper activation rules.

## 4. Update Main App to Handle Deep Links

Add the following to your `LocApp.swift` or `AppDelegate.swift`:

```swift
// Handle deep links from share extension
.onOpenURL { url in
    if url.scheme == "loc" && url.host == "share" && url.path == "/tiktok" {
        // Extract the TikTok URL from query parameters
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let urlItem = components.queryItems?.first(where: { $0.name == "url" }),
           let tiktokURLString = urlItem.value {
            // Handle the TikTok URL
            handleSharedTikTokURL(tiktokURLString)
        }
    }
}
```

## 5. Test the Share Extension

1. Build and run your app on a device or simulator
2. Open TikTok
3. Find a video you want to share
4. Tap the share button
5. Your app should now appear in the share sheet
6. Select your app to share the video

## 6. Optional: Customize the Share UI

You can customize the share extension UI by:
- Modifying the `MainInterface.storyboard`
- Creating a custom view controller instead of using `SLComposeServiceViewController`
- Adding custom configuration items

## Notes

- The share extension has a memory limit (around 120MB), so avoid loading heavy resources
- The extension runs in a separate process from your main app
- Data sharing between the extension and main app must use App Groups or URL schemes