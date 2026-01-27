# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Mesa (Loc) is a social iOS app for sharing and discovering places. Built with SwiftUI and Supabase, it allows users to create lists of restaurants, cafes, and other locations, share them with friends, and discover new places through their social network.

**📚 For detailed architecture guidance, see `ARCHITECTURE.md`**

## ⚠️ Core Principles (ALWAYS FOLLOW)

### Architecture Standards
- **STRICT MVVM ARCHITECTURE**: All code MUST follow Model-View-ViewModel architecture without exception
  - **Model**: Data structures and business entities only
  - **View**: Purely declarative UI with zero business logic
  - **ViewModel**: All business logic, state management, and data coordination
  - Never bypass MVVM for "quick fixes" or "simple cases"

### Single Responsibility Principle (SRP)
- **ONE REASON TO CHANGE**: Every class, struct, and function should have exactly one reason to change
- **FOCUSED COMPONENTS**: Each component does one thing and does it well
- **CLEAR BOUNDARIES**: If a component has multiple responsibilities, split it immediately
- **NO GOD OBJECTS**: Avoid classes/structs that know or do too much

### Code Quality Standards
- **STAFF ENGINEER LEVEL**: All code must meet staff engineer quality standards:
  - Clean, readable, and self-documenting code
  - Proper error handling and edge case coverage
  - Thoughtful API design and abstractions
  - Performance-conscious implementations
  - Maintainable and extensible architecture
  - No shortcuts or technical debt without explicit documentation

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

**🎯 Core Pattern: Smart vs Dumb Components with MVVM**

See `ARCHITECTURE.md` for complete details. Quick reference:

### Golden Rules
1. **One View, One ViewModel** - Each view has exactly one primary ViewModel
2. **Smart vs Dumb** - Behavior needs ViewModel, display doesn't
3. **ViewModels depend on Services**, not other ViewModels
4. **Views are DUMB** (purely declarative), ViewModels are SMART (business logic)

### File Organization
- **Models**: Data structures in `loc/Models/`
- **Views**: SwiftUI views in `loc/Views/` (purely declarative)
- **ViewModels**: Business logic in `loc/ViewModels/` (one per view)
- **Services**: Data layer in `loc/Services/` (Supabase, APIs)

### Key Services
- **ServiceContainer**: Dependency injection at `loc/Services/ServiceContainer.swift`
- **SupabaseAuthService**: User authentication
- **SupabasePlaceService**: Place data operations
- **SupabaseReviewService**: Review management
- **ImageService**: Photo handling

### Example: Smart vs Dumb
```swift
// DUMB: Just display data
struct PlaceInfoSection: View {
    let place: DetailPlace
    var body: some View { /* UI only */ }
}

// SMART: Has ViewModel for behavior
struct TikTokVideosSection: View {
    @ObservedObject var viewModel: TikTokVideosViewModel
    var body: some View { /* Observes ViewModel */ }
}
```

## Documentation Standards

### Function Comments
- **ONE COMMENT PER FUNCTION**: Every function MUST have exactly one comment directly above it
- **DESCRIBE THE BEHAVIOR**: The comment must clearly describe what the function does, not how
- **KEEP COMMENTS UPDATED**: When a function's behavior changes, the comment MUST be updated immediately
- **NO STALE COMMENTS**: A wrong comment is worse than no comment - always verify accuracy

### Comment Format
```swift
/// Fetches user places from the database and updates the local cache.
func fetchUserPlaces() async throws { ... }

/// Calculates the distance between two coordinates in meters.
func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double { ... }

/// Validates the input form and returns any validation errors found.
func validateForm() -> [ValidationError] { ... }
```

### Comment Rules
- Use `///` for documentation comments (Swift standard)
- Start with a verb (Fetches, Calculates, Validates, Returns, etc.)
- Be specific but concise (one sentence is ideal)
- Include parameter context only if not obvious from names
- Update comment FIRST when modifying function behavior

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

### Git Commit Rules
- **NEVER COMMIT WITHOUT USER TESTING**: All code changes MUST be tested by the user before committing
- **WAIT FOR CONFIRMATION**: After implementing changes, wait for explicit user confirmation that the feature works
- **NO PREMATURE COMMITS**: Do not commit based on assumptions or theoretical correctness
- **TEST FIRST, COMMIT SECOND**: The workflow is always: implement → user tests → user confirms → then commit
- **REVERT MISTAKES IMMEDIATELY**: If a commit causes issues, revert it immediately and fix properly

### Acceptable in Views
- `var body: some View { ... }`
- Simple computed properties for formatting (e.g., `var formattedDate: String`)
- `@State` for simple UI state
- `@EnvironmentObject` and `@ObservedObject` property wrappers
- View modifiers and layout code

### Violations to Flag and Fix
1. **Multiple struct View declarations in one file**
2. **Functions defined inside View structs**
3. **Business logic in View bodies**
4. **Network calls or async operations in Views**
5. **Complex data manipulation in Views**
6. **Functions longer than 30 lines**
7. **MVVM violations**: Any code that bypasses the MVVM architecture
8. **SRP violations**: Components with multiple responsibilities
9. **Missing function comments**: Functions without a describing comment
10. **Stale comments**: Comments that don't match the function's current behavior
11. **Sub-standard code quality**: Code that doesn't meet staff engineer standards

### Migration Strategy
When finding violations:
1. **Extract Views**: Move additional View structs to their own files
2. **Extract Functions**: Move functions to appropriate ViewModels
3. **Create ViewModels**: If no ViewModel exists, create one for the business logic
4. **Update Dependencies**: Ensure proper `@EnvironmentObject` setup
5. **Refactor Long Functions**: Break functions longer than 30 lines into smaller, focused functions

## Enforcement

- Every Pull Request should be checked against these rules
- Use these rules during code review
- Refactor existing code when making changes to follow these patterns
- These standards are enforced to maintain code quality, readability, and proper MVVM architecture
- Every code change should be reviewed against these rules