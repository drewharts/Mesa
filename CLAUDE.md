# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Mesa (Loc) is a social iOS app for sharing and discovering places. Built with SwiftUI and Firebase, it allows users to create lists of restaurants, cafes, and other locations, share them with friends, and discover new places through their social network.

## Development Commands

### Build and Run
```bash
# Open in Xcode
open Loc.xcodeproj

# IMPORTANT: DO NOT run xcodebuild commands via CLI
# User prefers to build and run from Xcode interface only
# xcodebuild -project Loc.xcodeproj -scheme Loc -configuration Debug build
# xcodebuild test -project Loc.xcodeproj -scheme Loc -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Firebase Functions
```bash
cd functions
npm install
npm run serve  # Local development
npm run deploy # Deploy to Firebase
```

### Testing Deep Links
```bash
# Test deep link in simulator
xcrun simctl openurl booted "loc://profile/userId"
xcrun simctl openurl booted "loc://place/placeId"
xcrun simctl openurl booted "loc://list/listId"
```

## Architecture

### MVVM Pattern
- **Models**: Data structures in `Loc/Models/`
- **Views**: SwiftUI views in `Loc/Views/`
- **ViewModels**: Business logic in `Loc/ViewModels/`
- **Services**: External integrations in `Loc/Services/`

### Key Services
- **ServiceContainer**: Dependency injection container at `Loc/Services/ServiceContainer.swift`
- **FirebaseService**: Firestore operations at `Loc/Services/FirebaseService.swift`
- **AuthenticationService**: User authentication at `Loc/Services/AuthenticationService.swift`
- **NotificationService**: Push notifications at `Loc/Services/NotificationService.swift`

### Data Flow
1. Views observe ViewModels via `@StateObject` or `@ObservedObject`
2. ViewModels interact with Services through ServiceContainer
3. Services handle Firebase/external API calls
4. Models define data structures with Codable for Firebase serialization

## Key Features Implementation

### Place Discovery
- **PlaceSearchView**: Google Places Autocomplete integration
- **MapView**: Combined Google Maps and Mapbox implementation
- **PlaceDetailView**: Multi-factor reviews with photo uploads

### Social Features
- **UserProfile**: Follow/unfollow system with activity feeds
- **ListSharing**: Public/private lists with collaborative editing
- **Notifications**: Real-time updates for likes, comments, follows

### Deep Linking
URL scheme: `loc://`
- Handled in `Loc/AppDelegate.swift` and `Loc/LocApp.swift`
- Routes: `/profile/{userId}`, `/place/{placeId}`, `/list/{listId}`

## Firebase Configuration

### Firestore Collections
- `users`: User profiles and settings
- `places`: Place details and reviews
- `lists`: User-created place lists
- `activities`: Social activity feed
- `notifications`: Push notification data

### Cloud Functions
Located in `functions/src/index.ts`:
- `onUserCreate`: Initialize new user data
- `onFollowCreate`: Send follow notifications
- `onActivityCreate`: Trigger activity notifications
- `sendNotification`: Helper for push notifications

## Testing Considerations

### Unit Tests
- Test ViewModels with mock services
- Firebase rules testing for security
- Deep link URL parsing tests

### UI Tests
- Test navigation flows
- Map interaction testing
- List creation/editing flows

## Common Issues and Solutions

### Firebase Authentication
- Check GoogleService-Info.plist is included
- Verify bundle ID matches Firebase config
- Test with Firebase Auth emulator for development

### Map Integration
- Ensure API keys are set in Info.plist
- Test both Google Maps and Mapbox fallbacks
- Handle location permissions properly

### Push Notifications
- Register for notifications in AppDelegate
- Test with Firebase Console
- Handle notification permissions gracefully

## Coding Standards and Architecture Rules

**IMPORTANT**: This project follows strict coding standards defined in `.cursorrules`. All code changes MUST adhere to these rules:

### File Organization Rules
- **ONE VIEW PER FILE**: Each SwiftUI View struct must be in its own separate file
- **NO MULTIPLE VIEWS**: Never create multiple View structs in a single file
- **FILE NAMING**: View files should be named exactly the same as the View struct they contain
- **LOCATION**: Place views in appropriate subdirectories under `/Views/`

### Function Organization
- **NO FUNCTIONS IN VIEWS**: Never define functions inside SwiftUI View structs
- **MOVE TO VIEWMODEL**: All business logic and functions should be moved to ViewModels
- **COMPUTED PROPERTIES ONLY**: Views should only contain computed properties for simple data transformation
- **VIEW BODY ONLY**: The view's body should focus purely on UI layout and presentation

### Function Length Guidelines
- **30-LINE LIMIT**: Functions should almost never exceed 30 lines of code
- **BREAK INTO PARTS**: Long functions should be broken into smaller, focused functions that improve readability
- **LOGICAL SEPARATION**: Split functions at natural logical boundaries (separate concerns, distinct operations)
- **MEANINGFUL NAMES**: Each extracted function should have a clear, descriptive name that explains its purpose
- **SINGLE RESPONSIBILITY**: Each function should have one clear responsibility or purpose

### ViewModels
- **BUSINESS LOGIC HOME**: All business logic, data fetching, and state management belongs in ViewModels
- **OBSERVABLE OBJECTS**: ViewModels should be `@MainActor class ViewModelName: ObservableObject`
- **PUBLISHED PROPERTIES**: Use `@Published` for properties that trigger UI updates
- **ASYNC FUNCTIONS**: Handle async operations in ViewModels, not Views

### SwiftUI Views
- **DECLARATIVE ONLY**: Views should be purely declarative UI descriptions
- **NO SIDE EFFECTS**: No network calls, database operations, or complex logic in Views
- **ENVIRONMENT OBJECTS**: Use `@EnvironmentObject` to access ViewModels
- **SIMPLE BINDINGS**: Only simple `@State` for local UI state like animations or temporary states

### Violations to Flag and Fix
1. **Multiple struct View declarations in one file**
2. **Functions defined inside View structs**
3. **Business logic in View bodies**
4. **Network calls or async operations in Views**
5. **Complex data manipulation in Views**
6. **Functions longer than 30 lines**

### Migration Strategy
When finding violations:
1. **Extract Views**: Move additional View structs to their own files
2. **Extract Functions**: Move functions to appropriate ViewModels
3. **Create ViewModels**: If no ViewModel exists, create one for the business logic
4. **Update Dependencies**: Ensure proper `@EnvironmentObject` setup
5. **Refactor Long Functions**: Break functions longer than 30 lines into smaller, focused functions

**Note**: These standards are enforced to maintain code quality, readability, and proper MVVM architecture. Every code change should be reviewed against these rules.