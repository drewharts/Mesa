# iOS App Architecture Guide

## 🎯 Core Principle: Smart vs Dumb Components with MVVM

This app follows a strict **MVVM (Model-View-ViewModel)** pattern with **Smart vs Dumb Components** composition.

---

## 🏗️ Architecture Layers

```
┌─────────────────────────────────────────────┐
│              Views (SwiftUI)                │
│  - Purely declarative UI                   │
│  - No business logic                       │
│  - Observes ViewModels                     │
└─────────────────────────────────────────────┘
                    ↓ observes
┌─────────────────────────────────────────────┐
│             ViewModels                      │
│  - Business logic                          │
│  - State management (@Published)           │
│  - Coordinates services                    │
│  - One ViewModel per View                  │
└─────────────────────────────────────────────┘
                    ↓ uses
┌─────────────────────────────────────────────┐
│              Services                       │
│  - Data access (API, Database)             │
│  - External integrations                   │
│  - Shared business rules                   │
└─────────────────────────────────────────────┘
                    ↓ operates on
┌─────────────────────────────────────────────┐
│               Models                        │
│  - Data structures (Codable)               │
│  - No business logic                       │
└─────────────────────────────────────────────┘
```

---

## ⚡ Golden Rules

### 1. **One View, One ViewModel**
Each view should have exactly ONE primary ViewModel that owns its business logic.

```swift
struct PlaceDetailTabsView: View {
    @ObservedObject var viewModel: PlaceDetailTabsViewModel  // Primary ViewModel
    
    var body: some View {
        // View code
    }
}
```

### 2. **Smart vs Dumb Components**

**DUMB Component:**
```swift
// Pure display - just pass data
struct PlaceInfoSection: View {
    let place: DetailPlace  // Data in
    
    var body: some View {
        Text(place.name)
        Text(place.description)
    }
}
```

**SMART Component:**
```swift
// Has behavior - needs ViewModel
struct TikTokVideosSection: View {
    @ObservedObject var viewModel: TikTokVideosViewModel
    
    var body: some View {
        if viewModel.isLoading {
            ProgressView()
        } else {
            // Display videos
        }
    }
}
```

### 3. **ViewModels Depend on Services, Not Other ViewModels**

```swift
✅ GOOD:
class MyViewModel: ObservableObject {
    private let placeService: PlaceService
    private let userService: UserService
}

❌ BAD:
class MyViewModel: ObservableObject {
    private let profileViewModel: ProfileViewModel
    private let selectedPlaceVM: SelectedPlaceViewModel
}
```

### 4. **Views Are Dumb, ViewModels Are Smart**

```swift
✅ Views should:
- Display data
- Handle UI state (animations, focus)
- Call ViewModel actions

❌ Views should NOT:
- Fetch data
- Contain business logic
- Have complex @State
- Make async calls directly
```

### 5. **Test ViewModels, Not Views**

Business logic lives in ViewModels, which are unit testable.

```swift
func testPlaceSelection() {
    let vm = PlaceDetailTabsViewModel(...)
    vm.selectTab(.reviews)
    XCTAssertEqual(vm.selectedTab, .reviews)
}
```

---

## 🎨 Component Decision Matrix

Ask this question: **"Does this component have BEHAVIOR?"**

| Criteria | Dumb Component | Smart Component |
|----------|----------------|-----------------|
| **Fetches data?** | ❌ No | ✅ Yes |
| **Has @State?** | ❌ Only UI state | ✅ Business state |
| **User interactions?** | Simple (toggle) | Complex (async) |
| **Business logic?** | ❌ Just formatting | ✅ Yes |
| **Needs ViewModel?** | ❌ No | ✅ Yes |
| **Line count** | < 50 lines | > 50 lines |

### Examples:

**DUMB:**
- `PlaceInfoSection` - Displays place rating and description
- Buttons, Labels, Simple UI components
- Formatters, Layout components

**SMART:**
- `TikTokVideosSection` - Fetches and manages TikTok videos
- `PlacePhotosView` - Loads and displays photo gallery
- Any component that fetches data or manages state

---

## 📁 File Organization

```
loc/
├── Models/                    # Data structures
│   ├── DetailPlace.swift
│   └── Review.swift
│
├── ViewModels/                # Business logic
│   ├── PlaceDetailTabsViewModel.swift      (Coordinator)
│   ├── AboutTabViewModel.swift             (Coordinator)
│   ├── TikTokVideosViewModel.swift         (Feature)
│   └── PlaceDetailViewModel.swift
│
├── Views/
│   ├── PlaceDetailViews/
│   │   ├── PlaceDetailTabsView.swift       (Coordinator View)
│   │   ├── AboutTabContent.swift           (Coordinator View)
│   │   ├── PlaceInfoSection.swift          (Dumb Component)
│   │   ├── TikTokVideosSection.swift       (Smart Component)
│   │   └── PlacePhotosView.swift           (Smart Component)
│   └── ...
│
└── Services/                  # Data layer
    ├── PlaceService.swift
    ├── ReviewService.swift
    └── ServiceContainer.swift
```

---

## 🎯 Real-World Example: AboutTabContent

### Before (Bad - 184 lines, mixed concerns):
```swift
struct AboutTabContent: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var userSession: UserSession
    
    @State private var tikTokVideos: [TikTokVideo] = []
    @State private var isLoadingTikToks: Bool = false
    
    var body: some View {
        // Rating display (inline)
        // Description display (inline)
        // TikTok fetching logic (inline)
        // TikTok display (inline)
        // Photos (inline)
    }
    
    private func loadTikTokVideos() async { ... }  // Business logic in view!
    private func deleteTikTok() async { ... }      // Business logic in view!
}
```

### After (Good - 52 lines, clear separation):
```swift
struct AboutTabContent: View {
    @ObservedObject var viewModel: AboutTabViewModel  // One ViewModel
    let onPhotoTapped: ([UIImage], Int) -> Void
    
    var body: some View {
        VStack {
            // 1. DUMB: Display only
            if let place = viewModel.place {
                PlaceInfoSection(place: place)
            }
            
            // 2. SMART: Has its own ViewModel
            TikTokVideosSection(
                viewModel: viewModel.tikTokVideosViewModel
            )
            
            // 3. SMART: Has its own ViewModel
            PlacePhotosView(
                viewModel: photosViewModel,
                onPhotoTapped: onPhotoTapped
            )
        }
    }
}
```

**Results:**
- ✅ 72% reduction in code
- ✅ No business logic in view
- ✅ All components reusable
- ✅ Easy to test
- ✅ Clear separation of concerns

---

## 🚀 How to Apply This Pattern

### Step 1: Identify Component Type
Ask: "Does this need to fetch data, manage state, or have business logic?"

### Step 2: Choose Pattern
- **NO** → Create dumb component, pass data as parameters
- **YES** → Create ViewModel + smart component

### Step 3: Create Files
```bash
# For dumb component (no ViewModel needed)
Views/MySimpleView.swift

# For smart component
ViewModels/MyFeatureViewModel.swift
Views/MyFeatureView.swift
```

### Step 4: Follow Template

**Dumb Component:**
```swift
struct MySimpleView: View {
    let data: MyData  // Just parameters
    let onAction: () -> Void
    
    var body: some View {
        // Pure UI
    }
}
```

**Smart Component:**
```swift
// ViewModel
@MainActor
class MyFeatureViewModel: ObservableObject {
    @Published var data: [Item] = []
    @Published var isLoading = false
    
    private let service: MyService
    
    init(service: MyService) {
        self.service = service
    }
    
    func loadData() async {
        isLoading = true
        data = await service.fetchData()
        isLoading = false
    }
}

// View
struct MyFeatureView: View {
    @ObservedObject var viewModel: MyFeatureViewModel
    
    var body: some View {
        if viewModel.isLoading {
            ProgressView()
        } else {
            List(viewModel.data) { item in
                Text(item.name)
            }
        }
        .task {
            await viewModel.loadData()
        }
    }
}
```

---

## ✅ Checklist for New Components

Before creating a component, ask:

- [ ] Does it fetch data? → Smart component
- [ ] Does it have business logic? → Smart component
- [ ] Does it manage state? → Smart component
- [ ] Is it just displaying data? → Dumb component
- [ ] Is the preview simple (< 20 lines)? → Good sign
- [ ] Can it be unit tested? → Should be yes for ViewModels
- [ ] Is it reusable elsewhere? → Design for reusability
- [ ] Does it follow single responsibility? → One job only

---

## 📚 Reference Files

### Architecture Examples (Keep These):
- `PROPER_MVVM_IMPLEMENTATION.md` - Initial refactoring of PlaceDetailTabsView
- `SMART_VS_DUMB_COMPONENTS.md` - AboutTab refactoring with component composition
- This file (`ARCHITECTURE.md`) - Overall architecture guide

### Key Implementation Files:
- `loc/ViewModels/PlaceDetailTabsViewModel.swift` - Coordinator ViewModel example
- `loc/ViewModels/AboutTabViewModel.swift` - Child coordinator example
- `loc/ViewModels/TikTokVideosViewModel.swift` - Feature ViewModel example
- `loc/Views/PlaceDetailViews/PlaceInfoSection.swift` - Dumb component example
- `loc/Views/PlaceDetailViews/TikTokVideosSection.swift` - Smart component example

---

## 🎓 Key Takeaways

1. **One View, One ViewModel** - Clear ownership
2. **Smart vs Dumb** - Behavior needs ViewModel, display doesn't
3. **Services, not ViewModels** - Depend on services layer
4. **Test ViewModels** - Business logic is unit testable
5. **Compose Components** - Build complex UIs from simple pieces

**This architecture enables:**
- 🧪 **Testability** - Unit test business logic
- ♻️ **Reusability** - Components work anywhere
- 🔧 **Maintainability** - Clear where to make changes
- 📈 **Scalability** - Pattern works at any scale
- 👥 **Team Velocity** - Clear conventions for everyone

---

*Last Updated: January 2025*
*Pattern Established by: Staff Engineer Architecture Review*

