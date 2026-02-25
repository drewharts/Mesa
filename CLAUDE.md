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
1. **One View, One ViewModel** - Each view has exactly one primary ViewModel (which may expose child ViewModels)
2. **Smart vs Dumb** - Behavior needs ViewModel, display doesn't
3. **ViewModels depend on Services**, not other ViewModels (use composition, not dependencies)
4. **Views are DUMB** (purely declarative), ViewModels are SMART (business logic)
5. **NO GOD VIEWMODELS** - Split large ViewModels into composed parent/child ViewModels by feature

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

## Testing Considerations

### Unit Tests
- Test ViewModels with mock services
- Deep link URL parsing tests

### UI Tests
- Test navigation flows
- Map interaction testing
- List creation/editing flows

## Common Issues and Solutions

### Supabase Authentication
- Verify Supabase URL and anon key are set correctly
- Check bundle ID matches Supabase project config
- See PUSH_NOTIFICATIONS_SETUP.md for push notification configuration

### Map Integration
- Ensure API keys are set in Info.plist
- Test both Google Maps and Mapbox fallbacks
- Handle location permissions properly

### Push Notifications
- Register for notifications in AppDelegate
- See PUSH_NOTIFICATIONS_SETUP.md for Supabase push notification setup
- Handle notification permissions gracefully

## Coding Standards and Architecture Rules

**IMPORTANT**: This project follows strict coding standards defined in `.cursorrules`. All code changes MUST adhere to these rules:

### File Organization Rules
- **ONE VIEW PER FILE**: Each SwiftUI View struct must be in its own separate file
- **NO MULTIPLE VIEWS**: Never create multiple View structs in a single file
- **FILE NAMING**: View files should be named exactly the same as the View struct they contain
- **LOCATION**: Place views in appropriate subdirectories under `/Views/`

### Reusable UI Components
- **EXTRACT COMMON PATTERNS**: When the same visual pattern (buttons, cards, pills, rows, badges, empty states, etc.) appears in more than one place, extract it into a reusable View struct
- **CONSISTENT STYLING**: Reusable components are the single source of truth for styling — colors, fonts, spacing, corner radii, shadows. Changing the component updates every usage
- **LOCATION**: Place shared components in `loc/Views/SharedComponents/`. Feature-specific components stay in their feature folder but must still be their own file
- **PARAMETERIZE BEHAVIOR, NOT STYLE**: Reusable components accept data and action closures as parameters. Style decisions (font, padding, colors) live inside the component, not at the call site
- **PREFER REUSE OVER DUPLICATION**: Before creating a new view, check if an existing shared component can be used or extended. Duplicated UI code is a violation

```swift
// BAD: Duplicated pill styling in multiple views
Text(label)
    .font(.subheadline)
    .fontWeight(isSelected ? .semibold : .regular)
    .padding(.horizontal, 14)
    .padding(.vertical, 8)
    .background(isSelected ? activeColor : Color(.systemGray6))
    .foregroundStyle(isSelected ? .white : .primary)
    .clipShape(Capsule())

// GOOD: Shared component owns the styling
struct FilterPill: View {
    let label: String
    let isSelected: Bool
    let activeColor: Color
    let onTap: () -> Void
    // All styling lives here — one place to update
}
```

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

### ViewModel Composition (NO GOD VIEWMODELS)

**CRITICAL**: Avoid "god" or "massive" ViewModels that handle too many responsibilities. Instead, use ViewModel composition where a parent/coordinating ViewModel owns or exposes focused child ViewModels.

#### Signs of a God ViewModel (REFACTOR IMMEDIATELY)
- More than 300-400 lines of code
- Handles more than 2-3 distinct feature areas
- Has 10+ `@Published` properties
- Methods that don't relate to each other
- Difficult to test in isolation
- Changes frequently for unrelated reasons

#### ViewModel Composition Pattern
```swift
// BAD: God ViewModel that does everything
@MainActor class ProfileViewModel: ObservableObject {
    // User data, favorites, lists, reviews, followers, following,
    // TikToks, notifications, settings... 500+ lines
}

// GOOD: Composed ViewModels with clear responsibilities
@MainActor class ProfileViewModel: ObservableObject {
    // Coordinates child ViewModels, handles profile-level state only
    @Published var user: User
    @Published var isLoading: Bool = false

    // Child ViewModels for specific features
    let favoritesViewModel: FavoritesViewModel
    let listsViewModel: ListsViewModel
    let reviewsViewModel: ReviewsViewModel
    let socialViewModel: SocialViewModel  // followers, following
}

@MainActor class FavoritesViewModel: ObservableObject {
    // ONLY handles favorites - loading, adding, removing, display
    @Published var favorites: [FavoritePlace] = []
    @Published var isLoading: Bool = false
}

@MainActor class ListsViewModel: ObservableObject {
    // ONLY handles lists - CRUD, sharing, collaboration
    @Published var lists: [PlaceList] = []
    @Published var isLoading: Bool = false
}
```

#### When to Split a ViewModel
1. **Feature boundaries**: Each distinct feature (favorites, lists, reviews) gets its own ViewModel
2. **Data domain**: Different data types that don't need to interact constantly
3. **Reusability**: When the same logic is needed in multiple places
4. **Testability**: When you can't easily unit test a piece in isolation
5. **Team ownership**: When different team members work on different features

#### Composition Rules
- **Parent coordinates, children execute**: Parent ViewModel manages lifecycle and cross-cutting concerns
- **Children are independent**: Each child ViewModel can function without knowing about siblings
- **Services are shared**: All ViewModels depend on Services, not each other
- **Views observe their ViewModel**: A View observes ONE primary ViewModel (which may expose children)

#### View Integration Example
```swift
struct ProfileView: View {
    @StateObject var viewModel: ProfileViewModel

    var body: some View {
        VStack {
            // Parent handles profile header
            ProfileHeaderView(user: viewModel.user)

            // Child ViewModels power child views
            FavoritesSection(viewModel: viewModel.favoritesViewModel)
            ListsSection(viewModel: viewModel.listsViewModel)
            ReviewsSection(viewModel: viewModel.reviewsViewModel)
        }
    }
}
```

#### Migration Strategy for God ViewModels
1. **Identify responsibilities**: List all distinct feature areas in the ViewModel
2. **Group related properties/methods**: Cluster by feature domain
3. **Extract child ViewModels**: Create focused ViewModels for each group
4. **Wire up composition**: Parent creates and exposes child ViewModels
5. **Update Views**: Views now observe appropriate child ViewModels
6. **Test in isolation**: Each child ViewModel should be independently testable

### Dependency Management (AVOID DEPENDENCY EXPLOSION)

**Environment Objects - Use Sparingly**
- Environment objects should be reserved for **truly app-wide state** (UserSession, theme settings)
- A view should have **at most 2-3** `@EnvironmentObject` dependencies
- If a view needs more, it's a sign the view is doing too much or dependencies should be injected differently
- **RED FLAG**: If you need to pass 5+ environment objects through a sheet, the architecture needs refactoring

**ViewModels Should Be Self-Sufficient**
- ViewModels should fetch their own service dependencies from `ServiceContainer.shared`
- ViewModels should NOT be passed as environment objects between unrelated views
- Instead, create new ViewModels that fetch their own dependencies

**Dependency Injection Pattern**
```swift
// BAD: View with many environment objects (dependency explosion)
struct MyView: View {
    @EnvironmentObject var serviceA: ServiceA
    @EnvironmentObject var viewModelA: ViewModelA
    @EnvironmentObject var viewModelB: ViewModelB
    @EnvironmentObject var viewModelC: ViewModelC
    // ... This is a code smell!
}

// GOOD: ViewModel fetches its own dependencies
@MainActor
class MyViewModel: ObservableObject {
    private let userService = ServiceContainer.shared.userService
    private let placeService = ServiceContainer.shared.placeService

    init(userId: String) {
        // ViewModel is self-sufficient, only needs data (IDs) not dependencies
    }
}

struct MyView: View {
    @StateObject var viewModel: MyViewModel
    @EnvironmentObject var userSession: UserSession  // Only truly global state
}
```

**Navigation Without Dependency Chains**
- When navigating to a new view, that view should create its own ViewModel
- Pass only **data** (IDs, simple values) through navigation, not ViewModels or services
- The destination view's ViewModel fetches its own dependencies from ServiceContainer

```swift
// BAD: Passing ViewModel through navigation
NavigationLink(destination: DetailView(viewModel: parentViewModel.childViewModel))

// GOOD: Pass data, let destination create its own ViewModel
NavigationLink(destination: DetailView(itemId: item.id))

struct DetailView: View {
    let itemId: String
    @StateObject private var viewModel: DetailViewModel

    init(itemId: String) {
        self.itemId = itemId
        self._viewModel = StateObject(wrappedValue: DetailViewModel(itemId: itemId))
    }
}
```

**Sheet Presentation Pattern**
- Use `sheet(item:)` instead of `sheet(isPresented:)` when sheet content depends on data
- This bundles "should show" and "what to show" atomically, avoiding state sync issues

```swift
// BAD: Separate state that can get out of sync
@State var selectedItem: Item?
@State var showSheet = false

// GOOD: Single atomic state
@State var selectedItem: Item?  // nil = no sheet, non-nil = show sheet
.sheet(item: $selectedItem) { item in
    DetailSheet(item: item)
}
```

### Reactive Data Patterns (Combine Best Practices)

**Subscribe to Data, Not Triggers**
- NEVER use manual trigger properties like `updateCounter` or `refreshFlag`
- Subscribe directly to `@Published` data properties
- Use Combine operators to filter and deduplicate

```swift
// BAD: Manual trigger pattern (code smell)
@Published var updateCounter: Int = 0  // Incremented to trigger updates

viewModel.$updateCounter
    .sink { _ in self.refreshData() }  // Subscribing to a trigger, not data

// GOOD: Subscribe to actual data changes
@Published var posts: [Post] = []

service.$postsCache
    .map { $0[placeId] ?? [] }
    .removeDuplicates()  // Prevent unnecessary updates
    .sink { posts in self.posts = posts }
```

**Use CombineLatest for Multi-Source Updates**
- When UI depends on multiple data sources, use `CombineLatest`
- This ensures updates when ANY source changes

```swift
// GOOD: React to changes in either currentPlace OR postsCache
Publishers.CombineLatest(
    $currentPlaceId,
    service.$postsCache
)
.map { placeId, cache in cache[placeId] ?? [] }
.removeDuplicates()
.sink { posts in self.updateUI(posts) }
```

**Service Layer Reactive Rules**
- Services expose `@Published` properties for cached data
- Services do NOT expose manual trigger mechanisms
- ViewModels subscribe to service publishers via Combine
- Use `receive(on: RunLoop.main)` for UI updates

```swift
// GOOD: Service with reactive properties
@MainActor
class PostsCacheService: ObservableObject {
    @Published private(set) var postsCache: [String: [Post]] = [:]
    @Published private(set) var loadingStates: [String: LoadingState] = [:]

    // NO updateCounter or similar triggers!
}

// GOOD: ViewModel subscribes reactively
@MainActor
class MyViewModel: ObservableObject {
    private let service = ServiceContainer.shared.postsCacheService

    func setupSubscriptions() {
        service.$postsCache
            .receive(on: RunLoop.main)
            .sink { [weak self] cache in
                self?.handleCacheUpdate(cache)
            }
            .store(in: &cancellables)
    }
}
```

### SwiftUI Views
- **DECLARATIVE ONLY**: Views should be purely declarative UI descriptions
- **NO SIDE EFFECTS**: No network calls, database operations, or complex logic in Views
- **ENVIRONMENT OBJECTS**: Use `@EnvironmentObject` sparingly - only for truly global state
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
12. **God ViewModels**: ViewModels with 300+ lines or 10+ @Published properties handling multiple features - must be split into composed child ViewModels
13. **Dependency Explosion**: Views with 4+ `@EnvironmentObject` dependencies - refactor to have ViewModels fetch their own dependencies from ServiceContainer
14. **Manual Trigger Patterns**: Using `updateCounter`, `refreshFlag`, or similar properties to trigger updates - subscribe to actual data changes instead
15. **Duplicated UI Patterns**: Copy-pasted styling (pills, cards, rows, badges, etc.) across multiple views instead of extracting a reusable shared component

### Migration Strategy
When finding violations:
1. **Extract Views**: Move additional View structs to their own files
2. **Extract Functions**: Move functions to appropriate ViewModels
3. **Create ViewModels**: If no ViewModel exists, create one for the business logic
4. **Update Dependencies**: Ensure proper `@EnvironmentObject` setup
5. **Refactor Long Functions**: Break functions longer than 30 lines into smaller, focused functions
6. **Split God ViewModels**: Decompose large ViewModels into parent/child composition by feature domain
7. **Extract Reusable Components**: When duplicated UI patterns are found, extract them into shared View structs in `loc/Views/SharedComponents/`

## Enforcement

- Every Pull Request should be checked against these rules
- Use these rules during code review
- Refactor existing code when making changes to follow these patterns
- These standards are enforced to maintain code quality, readability, and proper MVVM architecture
- Every code change should be reviewed against these rules