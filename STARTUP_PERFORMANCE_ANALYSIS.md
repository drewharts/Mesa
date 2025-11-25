# 🐌 Startup Performance Problem - Root Cause Analysis

## The Problem

Despite viewport optimization, app startup is STILL slow because we're loading **THOUSANDS of place documents** before showing the map.

## What's Actually Happening on Startup

### Current Flow (❌ SLOW):

```
Login → DataManager.initializeProfileData() 
  ↓
PHASE 1 (BLOCKS UI):
  - loadUserMyPlaces()        → Loads ALL user's places (50+ docs)
  - loadUserFavoritePlaces()  → Loads ALL favorites (6+ docs) 
  - loadProfileData()         → 1 doc ✅ Fast
  ↓
PHASE 2 (BLOCKS UI):
  - loadUserPlaceLists()      → Loads ALL lists + ALL places in lists (100+ docs)
  - loadUserReviewedPlaces()  → Loads ALL places user reviewed (50+ docs)
  - loadFollowing()           → Loads following profiles ✅
  ↓
PHASE 3 (Background but still expensive):
  - For EACH friend (e.g. 20 friends):
    • loadUserFavoritePlaces(friend) → 6 places × 20 = 120 docs
    • loadUserPlaceLists(friend)     → 50 places × 20 = 1,000 docs
    • loadUserReviewedPlaces(friend) → 30 places × 20 = 600 docs
  ↓
TOTAL: ~2,000+ Firestore document reads BEFORE map shows
```

**Result**: 3-5 second wait before map appears 😔

## The Core Issue

We're loading **full DetailPlace documents** for:
- All user's places
- All user's favorites
- All places in all user's lists
- All places user reviewed
- All places friends favorited
- All places in friends' lists
- All places friends reviewed

**But the user can only see ~50 places on screen at once!**

## The Solution: Load ONLY What's Needed

### New Flow (✅ FAST):

```
Login → Minimal Data Load
  ↓
PHASE 1 (INSTANT - < 0.3s):
  - Load user profile         → 1 doc ✅
  - Load place IDs ONLY:
    • myPlaceIds: [id1, id2, ...] → 0 docs (just metadata)
    • favoriteIds: [id1, id2, ...] → 0 docs (just metadata)
    • listIds: [id1, id2, ...] → 0 docs (just metadata)
  - Load friend IDs           → 1 query ✅
  ↓
Map shows immediately with loading indicator
  ↓
PHASE 2 (PARALLEL - viewport only):
  - loadViewportPlaces()         → 50 docs (viewport)
  - loadViewportFriendsPlaces()  → 20 docs (viewport)
  - Load full details for user's favorited places IN VIEWPORT ONLY
  ↓
TOTAL: ~70-80 Firestore reads for instant map
```

**Result**: Map appears in 0.3-0.5 seconds 🚀

---

## Required Changes

### 1. Change Firestore Structure (Optional but Recommended)

**Current Structure:**
```
users/{userId}/
  - favorites: [placeId1, placeId2, ...]  ✅ Already lightweight!
  - myPlaces: [placeId1, placeId2, ...]   ✅ Already lightweight!
  - placeLists/{listId}/
      - places: [Place objects]           ❌ Heavy!
```

**Proposed Structure:**
```
users/{userId}/
  - favorites: [placeId1, placeId2, ...]  ✅
  - myPlaces: [placeId1, placeId2, ...]   ✅
  - placeLists/{listId}/
      - placeIds: [id1, id2, ...]         ✅ Lightweight!
      - (keep places array for backward compat)
```

### 2. Rewrite DataManager Loading Logic

**Key Principle**: Load IDs on startup, load full details on-demand.

#### A. Startup - Load Metadata Only

```swift
func initializeProfileData(userId: String) async {
    // PHASE 1: Load minimal data (< 0.3s)
    async let profile = loadProfileData(userId)
    async let placeIds = loadUserPlaceIds(userId)  // NEW: Just IDs
    async let friendIds = loadFriendIds(userId)    // NEW: Just IDs
    
    await (profile, placeIds, friendIds)
    
    // Map can show NOW with viewport loading
    
    // PHASE 2: Load place details for viewport in background
    // This happens via MapViewModel automatically
}

// NEW: Just load the IDs, not full place documents
private func loadUserPlaceIds(userId: String) async {
    do {
        // Load favorites (already just IDs)
        let favoriteIds = try await userService.fetchFavoritePlaceIds(userId)
        profileViewModel.userFavorites = favoriteIds
        
        // Load myPlaces (already just IDs)
        let myPlaceIds = try await placeService.fetchMyPlaceIds(userId)
        profileViewModel.myPlaces = myPlaceIds
        
        // Load list metadata (list names + placeIds, not full places)
        let lists = try await placeService.fetchListMetadata(userId)
        profileViewModel.userLists = lists
        
        // Total: Maybe 3 document reads instead of 200+
    } catch {
        print("Error loading place IDs: \(error)")
    }
}
```

#### B. On-Demand Loading

```swift
// When user opens their profile → Load full details
func loadProfilePlaces() async {
    let allPlaceIds = profileViewModel.userFavorites + 
                      profileViewModel.myPlaces +
                      profileViewModel.userLists.flatMap { $0.placeIds }
    
    // Deduplicate
    let uniqueIds = Array(Set(allPlaceIds))
    
    // Load in batches
    let places = try await placeService.fetchPlacesByIds(uniqueIds)
    // Store in detailPlaceViewModel
}

// When user opens a specific list → Load those places only
func loadListPlaces(listId: UUID) async {
    guard let list = profileViewModel.userLists.first(where: { $0.id == listId }) else { return }
    
    let places = try await placeService.fetchPlacesByIds(list.placeIds)
    // Store in detailPlaceViewModel
}
```

### 3. Stop Loading Friends' Places Data Upfront

**Current** (line 396-410 in DataManager):
```swift
// Loads ALL favorites + lists for ALL friends on startup
await loadFollowingPlacesDataOptimized(profiles: profiles)
```

**New** (just load IDs):
```swift
// Only load friend IDs, not their places
// Places will be loaded via viewport queries automatically
```

---

## Implementation Steps

### Step 1: Add ID-Only Queries (Firestore)

```swift
// UserService.swift
func fetchFavoritePlaceIds(userId: String) async throws -> [String] {
    let doc = try await db.collection("users").document(userId).getDocument()
    return doc.data()?["favorites"] as? [String] ?? []
}

// PlaceService.swift
func fetchMyPlaceIds(userId: String) async throws -> [String] {
    let snapshot = try await db.collection("places")
        .whereField("userId", isEqualTo: userId)
        .getDocuments()
    return snapshot.documents.map { $0.documentID }
}

func fetchListMetadata(userId: String) async throws -> [PlaceList] {
    let snapshot = try await db.collection("users")
        .document(userId)
        .collection("placeLists")
        .getDocuments()
    
    return snapshot.documents.compactMap { doc -> PlaceList? in
        // Only decode list metadata, not full place documents
        let data = doc.data()
        let placeIds = (data["places"] as? [[String: Any]])?.map { 
            $0["id"] as? String 
        }.compactMap { $0 } ?? []
        
        return PlaceList(
            id: UUID(uuidString: doc.documentID) ?? UUID(),
            name: data["name"] as? String ?? "",
            image: data["image"] as? String,
            placeIds: placeIds  // NEW: Just store IDs
        )
    }
}
```

### Step 2: Update DataManager

```swift
func initializeProfileData(userId: String) async {
    let startTime = Date()
    
    // ONLY load metadata - FAST!
    async let profile = loadProfileData(userId)
    async let placeIds = loadUserPlaceIds(userId)
    async let friendIds = loadFriendIds(userId)
    
    await (profile, placeIds, friendIds)
    
    let loadTime = Date().timeIntervalSince(startTime)
    print("✅ Initial data loaded in \(loadTime)s")  // Should be < 0.3s
    
    // Map shows now!
    // Viewport places load via MapViewModel automatically
    
    // Background: Load full details for user's saved places that are in viewport
    Task.detached {
        await self.loadSavedPlacesInViewport()
    }
}

private func loadUserPlaceIds(userId: String) async {
    // Just load IDs, not full place documents
    async let favorites = try? await userService.fetchFavoritePlaceIds(userId)
    async let myPlaces = try? await placeService.fetchMyPlaceIds(userId)
    async let lists = try? await placeService.fetchListMetadata(userId)
    
    let (favIds, myPlaceIds, listMetadata) = await (favorites, myPlaces, lists)
    
    profileViewModel.userFavorites = favIds ?? []
    profileViewModel.myPlaces = myPlaceIds ?? []
    profileViewModel.userLists = listMetadata ?? []
}

private func loadFriendIds(userId: String) async {
    // Just load friend IDs
    let friendIds = try? await userService.fetchFriendIds(userId)
    
    // Pass to MapViewModel for viewport filtering
    await MainActor.run {
        profileViewModel.mapViewModel?.updateFriendIds(friendIds ?? [])
    }
}
```

### Step 3: Remove Heavy Loading from Startup

**Delete these from startup flow:**
- ❌ `loadUserMyPlaces()` - Loads full place documents
- ❌ `loadUserFavoritePlaces()` - Loads full place documents
- ❌ `loadUserPlaceLists()` - Loads full place documents
- ❌ `loadUserReviewedPlaces()` - Loads full place documents
- ❌ `loadFollowingPlacesDataOptimized()` - Loads friends' place documents

**Keep only:**
- ✅ `loadProfileData()` - User profile (1 doc)
- ✅ `loadUserPlaceIds()` - Just IDs (1-3 docs)
- ✅ `loadFriendIds()` - Friend IDs (1 query)

### Step 4: Add Lazy Loading

```swift
// When user opens profile view
func loadProfileData() async {
    let allIds = Set(profileViewModel.userFavorites + profileViewModel.myPlaces)
    let places = try? await placeService.fetchPlacesByIds(Array(allIds))
    // Store in detailPlaceViewModel
}

// When user opens a specific list
func loadList(listId: UUID) async {
    guard let list = profileViewModel.userLists.first(where: { $0.id == listId }) else { return }
    let places = try? await placeService.fetchPlacesByIds(list.placeIds)
    // Store in detailPlaceViewModel
}
```

---

## Expected Results

### Before:
```
Startup sequence:
1. Load user data                   → 0.5s
2. Load ALL user places             → 1.0s (200+ docs)
3. Load ALL friends' places         → 2.0s (1,000+ docs)
4. Calculate annotations            → 0.5s
5. Show map                         → FINALLY!

Total: 4.0s 😔
Firestore reads: 2,000+
```

### After:
```
Startup sequence:
1. Load user metadata (IDs only)    → 0.2s (3 docs)
2. Load friend IDs                  → 0.1s (1 query)
3. Show map with loading indicator  → 0.3s ✅
4. Load viewport places (parallel)  → 0.2s (70 docs)
5. Map fully loaded                 → 0.5s 🚀

Total: 0.5s 😍
Firestore reads: 70-80
```

**Improvement:**
- ⚡ **8x faster** startup (0.5s vs 4.0s)
- 📉 **96% fewer** Firestore reads (80 vs 2,000)
- 💾 **97% less** bandwidth
- 💰 **Massive** cost savings

---

## Migration Strategy

### Phase 1: Add ID-Only Methods (No Breaking Changes)
- Add `fetchFavoritePlaceIds()`, `fetchMyPlaceIds()`, `fetchListMetadata()`
- Keep old methods for backward compatibility
- Test new methods work correctly

### Phase 2: Update DataManager (One-Line Toggle)
- Add feature flag: `USE_LAZY_LOADING = true`
- If true: Use new ID-only startup
- If false: Use old full-load startup
- Deploy to 10% of users

### Phase 3: Monitor & Roll Out
- Monitor startup times in Analytics
- Check for any issues with lazy loading
- Roll out to 100% if successful

### Phase 4: Cleanup (Optional)
- Remove old heavy loading methods
- Remove feature flag

---

## The Core Principle

**Load data JUST-IN-TIME, not JUST-IN-CASE**

- ❌ Don't load ALL places hoping user might view them
- ✅ Load ONLY what's visible right now
- ✅ Load more when user actually needs it

This is how Google Maps, Uber, Airbnb, etc. all work - they don't load the entire world on startup! 🌎
