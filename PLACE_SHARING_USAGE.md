# Place Sharing - Quick Start Guide

## Overview
The place sharing functionality is now available! Users can share places via deep links using the `PlaceShareService`.

## Simple Usage

### Adding Share Buttons to Your Views

```swift
// In any view where you have a DetailPlace
struct PlaceDetailView: View {
    let place: DetailPlace
    @EnvironmentObject private var serviceContainer: ServiceContainer
    
    var body: some View {
        VStack {
            // Your existing place details
            Text(place.name)
            
            // Add the share button
            Button("Share Place") {
                Task { @MainActor in
                    serviceContainer.placeShareService.sharePlace(place)
                }
            }
        }
    }
}
```

### For NearbyPlace Features

```swift
// In views with NearbyPlaceFeature
struct NearbyPlaceRow: View {
    let nearbyPlace: NearbyPlaceFeature
    @EnvironmentObject private var serviceContainer: ServiceContainer
    
    var body: some View {
        HStack {
            Text(nearbyPlace.properties.name)
            Spacer()
            
            Button(action: {
                Task { @MainActor in
                    serviceContainer.placeShareService.sharePlace(nearbyPlace)
                }
            }) {
                Image(systemName: "square.and.arrow.up")
            }
        }
    }
}
```

### Using Pre-built Components

The app includes ready-to-use share button components:

```swift
// For DetailPlace
PlaceShareButton(place: detailPlace)
    .environmentObject(serviceContainer)

// For NearbyPlaceFeature  
NearbyPlaceShareButton(nearbyPlace: nearbyPlaceFeature)
    .environmentObject(serviceContainer)
```

## Features Available

✅ **Generate shareable URLs** - Creates `loc://place/[id]?params...` URLs  
✅ **Native share sheet** - Uses iOS native sharing UI  
✅ **Copy to clipboard** - Quick copy functionality  
✅ **URL scheme configured** - App can handle `loc://` URLs  

## Testing

### Test URL Generation
```swift
let shareURL = serviceContainer.placeShareService.generateShareURL(for: detailPlace)
print("Generated URL: \(shareURL)")
```

### Test Deep Links (iOS Simulator)
```bash
xcrun simctl openurl booted "loc://place/test-id?name=Test%20Place&address=123%20Main%20St"
```

## Next Steps

The foundation is complete! You can now:

1. **Add share buttons** to your existing place detail views
2. **Test the sharing** functionality with the native share sheet
3. **Expand deep link handling** as needed for your app's navigation

The deep link URLs are generated automatically and will work for sharing places between users! 