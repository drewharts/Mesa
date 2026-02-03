# Enterprise Architecture Options for Posts/Feed

## Current State (Pragmatic MVVM)

```
PlacePostsCacheService (singleton)
    ↓ Combine $updateCounter
SelectedPlaceVM / PlaceDetailTabsVM
```

**Pros**: Simple, works, follows existing CLAUDE.md patterns
**Cons**: updateCounter hack, singleton testing issues, no cache policy

---

## Option 1: Repository Pattern (Recommended Upgrade)

This is what Instagram, Twitter, and most enterprise iOS apps use.

```
┌─────────────────────────────────────────────────────────┐
│                      ViewModel                          │
│  - Requests data from Repository                        │
│  - Doesn't know about network vs cache                  │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│                 PostsRepository                         │
│  - Single source of truth                               │
│  - Coordinates cache + network                          │
│  - Exposes Publisher<[Post], Never>                     │
└─────────────────────────────────────────────────────────┘
                    │              │
                    ▼              ▼
┌──────────────────────┐  ┌──────────────────────┐
│   PostsCache         │  │   PostsNetworkService│
│   (Memory + Disk)    │  │   (API calls only)   │
└──────────────────────┘  └──────────────────────┘
```

### Example Implementation

```swift
// MARK: - Repository Protocol (for testing)
protocol PostsRepositoryProtocol {
    func posts(forPlaceId: String) -> AnyPublisher<[PlacePost], Never>
    func loadPosts(forPlaceId: String) async throws
    func addPost(_ post: PlacePost, forPlaceId: String)
    func deletePost(postId: String, forPlaceId: String) async throws
}

// MARK: - Repository Implementation
@MainActor
class PostsRepository: PostsRepositoryProtocol, ObservableObject {

    // MARK: - Published State (ViewModels subscribe to these directly)
    @Published private(set) var postsByPlace: [String: [PlacePost]] = [:]
    @Published private(set) var loadingStates: [String: LoadingState] = [:]

    // MARK: - Dependencies (injected, not singleton)
    private let networkService: PostsNetworkServiceProtocol
    private let cache: PostsCacheProtocol

    init(networkService: PostsNetworkServiceProtocol, cache: PostsCacheProtocol) {
        self.networkService = networkService
        self.cache = cache
    }

    // MARK: - Reactive Access (no updateCounter needed!)
    func posts(forPlaceId placeId: String) -> AnyPublisher<[PlacePost], Never> {
        $postsByPlace
            .map { $0[placeId] ?? [] }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    // MARK: - Load with Cache-First Strategy
    func loadPosts(forPlaceId placeId: String) async throws {
        loadingStates[placeId] = .loading

        // 1. Return cached data immediately (if available)
        if let cached = cache.posts(forPlaceId: placeId) {
            postsByPlace[placeId] = cached
        }

        // 2. Fetch fresh data from network
        do {
            let freshPosts = try await networkService.fetchPosts(placeId: placeId)
            postsByPlace[placeId] = freshPosts
            cache.store(posts: freshPosts, forPlaceId: placeId)
            loadingStates[placeId] = .loaded
        } catch {
            // Keep cached data on error, just update state
            loadingStates[placeId] = postsByPlace[placeId]?.isEmpty == false ? .loaded : .error(error)
            throw error
        }
    }
}

// MARK: - ViewModel subscribes to Repository
@MainActor
class PlaceDetailTabsViewModel: ObservableObject {
    @Published var posts: [PlacePost] = []

    private let postsRepository: PostsRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()

    init(postsRepository: PostsRepositoryProtocol) {
        self.postsRepository = postsRepository
    }

    func observePosts(forPlaceId placeId: String) {
        postsRepository.posts(forPlaceId: placeId)
            .receive(on: RunLoop.main)
            .sink { [weak self] posts in
                self?.posts = posts
                self?.updateUI()
            }
            .store(in: &cancellables)
    }
}
```

### Why This Is Better

1. **No `updateCounter` hack** - ViewModels subscribe to actual data changes
2. **Testable** - Inject mock repository for unit tests
3. **Cache-first** - Shows cached data immediately, then updates
4. **Separation of concerns** - Cache, Network, and Coordination are separate
5. **Protocol-based** - Easy to swap implementations

---

## Option 2: The Composable Architecture (TCA)

Used by: Airbnb, some teams at Google

```swift
// State
struct PlaceDetailState: Equatable {
    var posts: [PlacePost] = []
    var loadingState: LoadingState = .idle
}

// Actions
enum PlaceDetailAction: Equatable {
    case loadPosts(placeId: String)
    case postsLoaded(Result<[PlacePost], Error>)
    case deletePost(postId: String)
}

// Reducer
let placeDetailReducer = Reducer<PlaceDetailState, PlaceDetailAction, PlaceDetailEnvironment> { state, action, env in
    switch action {
    case .loadPosts(let placeId):
        state.loadingState = .loading
        return env.postsClient.fetchPosts(placeId)
            .map(PlaceDetailAction.postsLoaded)
            .eraseToEffect()

    case .postsLoaded(.success(let posts)):
        state.posts = posts
        state.loadingState = .loaded
        return .none

    case .postsLoaded(.failure(let error)):
        state.loadingState = .error(error)
        return .none
    }
}
```

**Pros**: Unidirectional data flow, time-travel debugging, highly testable
**Cons**: Steep learning curve, significant rewrite, adds dependency

---

## Option 3: Improve Current Implementation (Minimal Changes)

If a full rewrite isn't feasible, here are incremental improvements:

### 3a. Replace updateCounter with proper Combine

```swift
// Instead of:
@Published private(set) var updateCounter: Int = 0

// Use:
@Published private(set) var postsByPlace: [String: [PlacePost]] = [:]

// ViewModel subscribes to:
postsCacheService.$postsByPlace
    .map { $0[placeId] ?? [] }
    .removeDuplicates()
    .sink { posts in ... }
```

### 3b. Add Cache Policy

```swift
struct CachedPosts {
    let posts: [PlacePost]
    let timestamp: Date
    let placeId: String

    var isStale: Bool {
        Date().timeIntervalSince(timestamp) > 300 // 5 min TTL
    }
}

class PlacePostsCacheService {
    private var cache: [String: CachedPosts] = [:]
    private let maxCacheSize = 50 // LRU eviction

    func loadPosts(forPlaceId placeId: String, forceRefresh: Bool = false) {
        if let cached = cache[placeId], !cached.isStale, !forceRefresh {
            // Use cached data
            return
        }
        // Fetch from network...
    }
}
```

### 3c. Make it Injectable for Testing

```swift
// Protocol
protocol PostsCacheServiceProtocol {
    var postsByPlace: Published<[String: [PlacePost]]>.Publisher { get }
    func loadPosts(forPlaceId: String)
}

// In ServiceContainer
var postsCacheService: PostsCacheServiceProtocol = PlacePostsCacheService.shared

// For tests
ServiceContainer.shared.postsCacheService = MockPostsCacheService()
```

---

## Recommendation

**For your current stage**: Go with **Option 3** (incremental improvements). You have a working app, and a full rewrite to Repository pattern or TCA would be a significant undertaking.

**Specific improvements to make now**:
1. Remove `updateCounter` - subscribe directly to `$postsByPlace`
2. Add cache TTL (5 min is reasonable)
3. Add protocol for testability

**Future consideration**: When you have more engineering resources or hit scaling issues, migrate to **Option 1 (Repository Pattern)**. It's the industry standard for production iOS apps.

---

## What Instagram Actually Does

Based on public engineering blog posts:
- **Repository pattern** with protocol-based dependencies
- **IGListKit** for efficient list diffing
- **Memory + disk cache** with LRU eviction
- **Offline-first** architecture (Core Data/Realm for persistence)
- **Background sync** for feed updates
- **Pagination** with cursor-based loading
- **Optimistic updates** (UI updates before server confirms)

You don't need all of this for a v1, but it's the direction to grow toward.
