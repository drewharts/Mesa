# Place Sharing & Deep Linking Guide

## Overview
The Loc app now supports sharing places via deep links! Users can send place links to others, and when clicked, the place will open directly in the app.

## Components Created

### 1. **ShareablePlace Model** (`loc/Models/ShareablePlace.swift`)
- Contains essential place data for sharing
- Generates deep link URLs in format: `loc://place/[placeId]?params...`
- Parses incoming URLs back to place data

### 2. **PlaceShareService** (`loc/Services/PlaceShareService.swift`)
- Handles place sharing functionality
- Generates shareable URLs and presents native share sheet
- Supports both `DetailPlace` and `NearbyPlaceFeature` types

### 3. **DeepLinkManager** (`loc/Services/DeepLinkManager.swift`)
- Processes incoming deep links
- Searches for existing places in database
- Creates minimal place data if not found
- Navigates to place detail view

### 4. **DeepLinkViewModel** (`loc/ViewModels/DeepLinkViewModel.swift`)
- Coordinates UI state for deep linking
- Manages deep link processing flow
- Integrates with existing ViewModels

### 5. **Share Button Components**
- `PlaceShareButton.swift` - For DetailPlace objects
- `NearbyPlaceShareButton.swift` - For NearbyPlaceFeature objects

## How to Use

### Adding Share Buttons to Views

```swift
// In a place detail view
PlaceShareButton(place: detailPlace)
    .environmentObject(serviceContainer)

// In a nearby places list
NearbyPlaceShareButton(nearbyPlace: nearbyPlaceFeature)
    .environmentObject(serviceContainer)
```

### Programmatic Sharing

```swift
// Share a DetailPlace
serviceContainer.placeShareService.sharePlace(detailPlace)

// Share a NearbyPlaceFeature
serviceContainer.placeShareService.sharePlace(nearbyPlaceFeature)

// Generate URL only
let shareURL = serviceContainer.placeShareService.generateShareURL(for: detailPlace)

// Copy to clipboard
serviceContainer.placeShareService.copyPlaceLink(detailPlace)
```

## Deep Link URL Format

```
loc://place/[placeId]?name=[placeName]&address=[address]&city=[city]&mapboxId=[mapboxId]&lat=[latitude]&lng=[longitude]
```

**Example:**
```
loc://place/123e4567-e89b-12d3-a456-426614174000?name=Central%20Park&address=New%20York,%20NY&lat=40.7829&lng=-73.9654
```

## Configuration

### URL Scheme Setup
The `loc://` URL scheme has been added to `Info.plist`:

```xml
<dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
        <string>loc</string>
    </array>
</dict>
```

### Service Integration
The `PlaceShareService` has been added to `ServiceContainer` and is available throughout the app via environment objects.

## Testing Deep Links

### iOS Simulator
```bash
xcrun simctl openurl booted "loc://place/123e4567-e89b-12d3-a456-426614174000?name=Test%20Place&address=123%20Main%20St&lat=40.7128&lng=-74.0060"
```

### Physical Device
1. Create a test note with the deep link URL
2. Tap the link to test the functionality
3. Or use Messages to send the link between devices

## Flow Diagram

```
User taps Share Button
        ↓
PlaceShareService generates URL
        ↓
Native share sheet appears
        ↓
User shares via text/email/etc
        ↓
Recipient clicks link
        ↓
DeepLinkManager processes URL
        ↓
Search for existing place in database
        ↓
Navigate to place detail view
```

## Integration Points

### Existing Views
Add share buttons to:
- Place detail views
- Place list items
- Map annotations
- Search results
- Profile place lists

### ViewModels
The system integrates with existing ViewModels:
- `DetailPlaceViewModel` for navigation
- `ServiceContainer` for service access
- Environment objects for state management

## Error Handling

The system gracefully handles:
- Invalid URLs
- Missing place data
- Network errors during place lookup
- Places not found in database

When a place isn't found in the database, the system creates a minimal `DetailPlace` object from the URL parameters to ensure the user can still view the place information.

## Security Considerations

- URLs contain only essential place data (no sensitive user information)
- Place IDs are UUID format for uniqueness
- All URL parameters are properly encoded/decoded
- No user-specific data is included in shareable links 