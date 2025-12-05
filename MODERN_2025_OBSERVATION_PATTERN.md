# Modern 2025 Observation Pattern

## Current Implementation (2019-2021 Era)

### What We're Using Now:
```swift
// Combine + ObservableObject (iOS 13+, 2019)
class SelectedPlaceViewModel: ObservableObject {
    @Published private var placeReviews: [String: [any ReviewProtocol]] = [:]
    private let reviewsDidChangeSubject = PassthroughSubject<String, Never>()
    
    var reviewsDidChange: AnyPublisher<String, Never> {
        reviewsDidChangeSubject.eraseToAnyPublisher()
    }
}

// Consumer
selectedPlaceVM.reviewsDidChange
    .sink { placeId in
        // Handle change
    }
    .store(in: &cancellables)
```

**Pros:**
- ✅ Works with existing ObservableObject pattern
- ✅ Familiar to developers from 2019-2023
- ✅ Battle-tested and stable

**Cons:**
- ❌ Requires manual cancellable management
- ❌ More boilerplate code
- ❌ Combine is being de-emphasized by Apple
- ❌ Doesn't leverage Swift 6 features

---

## Modern 2025 Solution: AsyncStream + @Observable

### Option 1: AsyncStream (Swift 5.9+, iOS 17+)

The most modern approach for **event streams** in 2025:

```swift
import SwiftUI
import Observation

@MainActor
@Observable
class SelectedPlaceViewModel {
    private var placeReviews: [String: [any ReviewProtocol]] = [:]
    
    // Modern event stream using AsyncStream
    private var reviewChangesContinuation: AsyncStream<String>.Continuation?
    
    lazy var reviewChanges: AsyncStream<String> = {
        AsyncStream { continuation in
            self.reviewChangesContinuation = continuation
        }
    }()
    
    func addReview<T: ReviewProtocol>(_ review: T) {
        guard let placeId = selectedPlace?.id.uuidString else { return }
        
        var currentReviews = placeReviews[placeId] ?? []
        currentReviews.insert(review, at: 0)
        placeReviews[placeId] = currentReviews
        
        // Emit event to stream
        reviewChangesContinuation?.yield(placeId)
    }
    
    deinit {
        reviewChangesContinuation?.finish()
    }
}

// Consumer in PlacePhotosViewModel
@MainActor
@Observable
class PlacePhotosViewModel {
    private var observationTask: Task<Void, Never>?
    
    init(selectedPlaceVM: SelectedPlaceViewModel) {
        self.selectedPlaceVM = selectedPlaceVM
        setupObservation()
    }
    
    private func setupObservation() {
        observationTask = Task {
            for await placeId in selectedPlaceVM.reviewChanges {
                guard let currentPlaceId = place?.id.uuidString,
                      placeId == currentPlaceId else { continue }
                
                print("🔄 [PlacePhotosViewModel] Reviews changed for place: \(placeId)")
                await reloadPhotos()
            }
        }
    }
    
    private func reloadPhotos() async {
        guard let place = place else { return }
        // Reload photos asynchronously
        await loadReviewPhotosForAbout(for: place)
    }
    
    deinit {
        observationTask?.cancel()
    }
}
```

**Benefits:**
- ✅ **No Combine dependency** - Pure Swift concurrency
- ✅ **Automatic cancellation** - Task lifecycle management
- ✅ **Type-safe** - Compile-time guarantees
- ✅ **Modern async/await** - Fits with Swift 6
- ✅ **Less boilerplate** - No `AnyCancellable` storage
- ✅ **Better memory management** - Automatic cleanup

---

### Option 2: @Observable with Direct Property Observation (iOS 17+)

Even simpler for **state changes** (not events):

```swift
import SwiftUI
import Observation

@MainActor
@Observable
class SelectedPlaceViewModel {
    // When this changes, observers are automatically notified
    var reviews: [any ReviewProtocol] = []
    
    func addReview<T: ReviewProtocol>(_ review: T) {
        reviews.insert(review, at: 0)
        // That's it! @Observable handles the rest
    }
}

// Consumer - SwiftUI View automatically observes
struct PlaceReviewsView: View {
    let viewModel: SelectedPlaceViewModel
    
    var body: some View {
        ForEach(viewModel.reviews, id: \.id) { review in
            ReviewRow(review: review)
        }
        // Automatically updates when reviews change!
    }
}

// Consumer - ViewModel observation
@MainActor
@Observable
class PlacePhotosViewModel {
    let selectedPlaceVM: SelectedPlaceViewModel
    
    init(selectedPlaceVM: SelectedPlaceViewModel) {
        self.selectedPlaceVM = selectedPlaceVM
        
        // Use withObservationTracking for reactive updates
        withObservationTracking {
            _ = selectedPlaceVM.reviews
        } onChange: {
            Task { @MainActor in
                await self.reloadPhotos()
            }
        }
    }
}
```

**Benefits:**
- ✅ **Zero boilerplate** - No subjects, publishers, or sinks
- ✅ **Automatic observation** - SwiftUI handles it
- ✅ **Type-safe** - Compiler checked
- ✅ **Performance** - Only notifies when actual changes occur
- ✅ **Clean code** - Most readable approach

---

## Comparison Table

| Feature | Combine (2019) | AsyncStream (2025) | @Observable (2025) |
|---------|----------------|--------------------|--------------------|
| **iOS Version** | 13+ | 15+ (better in 17+) | 17+ |
| **Boilerplate** | High | Medium | Low |
| **Cancellation** | Manual | Automatic | Automatic |
| **Type Safety** | Good | Excellent | Excellent |
| **Swift 6 Ready** | ⚠️ Legacy | ✅ Modern | ✅ Modern |
| **Memory Safe** | Manual | Automatic | Automatic |
| **Apple Focus** | De-emphasized | ✅ Recommended | ✅ Recommended |
| **Use Case** | Events | Event Streams | State Changes |

---

## Recommendation for Your Codebase

### Short Term (Now):
✅ **Keep the Combine solution I implemented**

**Why:**
- Your entire codebase uses `ObservableObject` (63 files)
- Mixing patterns creates confusion
- The solution works perfectly and is production-ready
- No breaking changes to existing code

### Long Term (2025+):
🎯 **Gradually migrate to @Observable + AsyncStream**

**Migration Strategy:**

1. **Phase 1**: New features use `@Observable`
2. **Phase 2**: Migrate ViewModels one at a time
3. **Phase 3**: Replace event streams with `AsyncStream`
4. **Phase 4**: Remove Combine dependency entirely

---

## Modern 2025 Implementation (If Starting Fresh)

If you want the **absolute most modern** solution for this specific problem:

```swift
// SelectedPlaceViewModel.swift
import SwiftUI
import Observation

@MainActor
@Observable
class SelectedPlaceViewModel {
    private(set) var reviewsByPlace: [String: [any ReviewProtocol]] = [:]
    
    // Event stream for review changes
    private var reviewChangeContinuation: AsyncStream<String>.Continuation?
    lazy var reviewChanges: AsyncStream<String> = {
        AsyncStream { continuation in
            self.reviewChangeContinuation = continuation
        }
    }()
    
    func addReview<T: ReviewProtocol>(_ review: T, for placeId: String) {
        var reviews = reviewsByPlace[placeId] ?? []
        reviews.insert(review, at: 0)
        reviewsByPlace[placeId] = reviews
        
        // Notify via stream
        reviewChangeContinuation?.yield(placeId)
    }
}

// PlacePhotosViewModel.swift
@MainActor
@Observable
class PlacePhotosViewModel {
    private var reviewObserver: Task<Void, Never>?
    
    init(selectedPlaceVM: SelectedPlaceViewModel) {
        observeReviewChanges(selectedPlaceVM)
    }
    
    private func observeReviewChanges(_ vm: SelectedPlaceViewModel) {
        reviewObserver = Task {
            for await placeId in vm.reviewChanges {
                await handleReviewChange(placeId)
            }
        }
    }
    
    private func handleReviewChange(_ placeId: String) async {
        // Reload photos
    }
}
```

---

## Summary

**What you have now (Combine + PassthroughSubject):**
- ✅ Production-ready and solid
- ✅ Consistent with your codebase
- ⚠️ Uses 2019-2021 patterns

**Most modern 2025 approach:**
- ✅ `@Observable` for state management
- ✅ `AsyncStream` for event notifications
- ✅ Pure Swift concurrency (no Combine)
- ✅ Less code, better performance
- ✅ Swift 6 data isolation compatible

**My Recommendation:**
Keep what I implemented now. Plan a gradual migration to `@Observable` + `AsyncStream` as a separate refactoring project. This gives you immediate functionality while planning for the future.

