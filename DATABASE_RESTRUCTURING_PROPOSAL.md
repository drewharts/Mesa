# 🏗️ Database Restructuring for Instant Map Loading

## Current Problems

### 1. Friends' Places Not Loading
- `friendUserIds` is empty because we skip loading following data on startup
- Can't query friends' places without knowing who friends are

### 2. Complex Compound Queries Are Slow
```swift
// Current query requires 5 conditions!
.whereField("latitude", isGreaterThanOrEqualTo: southLat)
.whereField("latitude", isLessThanOrEqualTo: northLat)  
.whereField("longitude", isGreaterThanOrEqualTo: westLng)
.whereField("longitude", isLessThanOrEqualTo: eastLng)
.whereField("userId", in: friendIds)  // Limited to 10 friends!
```

### 3. Firestore Limitations
- Compound queries require composite indexes
- `in` operator limited to 10 items (need batching for 10+ friends)
- Geographic queries are inherently slow

## 🎯 The Solution: Pre-Computed Map Tiles

### New Database Structure

```
/map_tiles/
  ├── tile_{geohash}/
  │   ├── places: [
  │   │   {
  │   │     id: "place-uuid",
  │   │     lat: 40.7128,
  │   │     lng: -74.0060,
  │   │     name: "Restaurant Name",
  │   │     userId: "user-id",
  │   │     type: "Restaurant",
  │   │     thumbnail: "url"  // Pre-computed small image
  │   │   }
  │   │ ]
  │   └── lastUpdated: timestamp

/user_map_cache/
  ├── {userId}/
  │   ├── visiblePlaces: [  // Pre-computed list of ALL places user should see
  │   │   {
  │   │     id: "place-uuid",
  │   │     lat: 40.7128,
  │   │     lng: -74.0060,
  │   │     name: "Restaurant Name",
  │   │     source: "friend" | "self" | "list",
  │   │     thumbnail: "url"
  │   │   }
  │   │ ]
  │   └── lastUpdated: timestamp
```

### Option 1: Geohash-Based Tiles (Recommended)

**How it works:**
1. Divide the world into tiles using geohashes
2. Pre-compute which places belong in each tile
3. Query only the tiles visible in viewport

**Benefits:**
- Single query per tile (super fast)
- No complex compound conditions
- Works at any zoom level
- Can cache tiles client-side

**Implementation:**
```swift
// Fast tile query - single condition!
func fetchMapTile(geohash: String) async -> [PlacePin] {
    let tile = try await db.collection("map_tiles")
        .document(geohash)
        .getDocument()
    
    return tile.data()?["places"] as? [PlacePin] ?? []
}

// On map pan/zoom
func loadVisibleTiles(viewport: MKCoordinateRegion) {
    let visibleGeohashes = getGeohashesForViewport(viewport)
    
    // Load only 4-9 tiles typically
    for geohash in visibleGeohashes {
        if !cachedTiles.contains(geohash) {
            let places = await fetchMapTile(geohash)
            displayPlaces(places)
        }
    }
}
```

### Option 2: User-Specific Pre-Computed Cache

**How it works:**
1. Cloud Function pre-computes all places a user should see
2. Combines: user's places + favorites + lists + friends' places
3. Single document read on startup!

**Benefits:**
- ONE Firestore read for ALL places
- Instant load (< 100ms)
- No client-side processing

**Implementation:**
```swift
// INSTANT load - single document!
func loadUserMapCache(userId: String) async -> [PlacePin] {
    let cache = try await db.collection("user_map_cache")
        .document(userId)
        .getDocument()
    
    return cache.data()?["visiblePlaces"] as? [PlacePin] ?? []
}
```

**Cloud Function to maintain cache:**
```javascript
// Triggered when user's data changes
exports.updateUserMapCache = functions.firestore
    .document('users/{userId}/favorites/{placeId}')
    .onWrite(async (change, context) => {
        const userId = context.params.userId;
        
        // Rebuild user's map cache
        const places = await getAllUserVisiblePlaces(userId);
        
        // Write to single cache document
        await db.collection('user_map_cache').doc(userId).set({
            visiblePlaces: places,
            lastUpdated: FieldValue.serverTimestamp()
        });
    });
```

### Option 3: Hybrid Approach (Best of Both)

1. **Instant startup**: Load user's cached places (1 read)
2. **Dynamic viewport**: Load geohash tiles for exploration
3. **Background sync**: Update cache periodically

## Implementation Plan

### Phase 1: Quick Win (1 day)
1. Pre-load friend IDs on startup (lightweight)
2. Cache viewport queries aggressively
3. Reduce initial viewport size

### Phase 2: User Cache (3 days)
1. Create Cloud Function to build user cache
2. Update cache on data changes
3. Load cache on startup

### Phase 3: Geohash Tiles (1 week)
1. Implement geohash system
2. Create tile generation functions
3. Client-side tile caching

## Expected Performance

| Approach | Load Time | Firestore Reads | Complexity |
|----------|-----------|-----------------|------------|
| Current | 1-2s | 50-200 | High |
| Quick Win | 500ms | 30-50 | Low |
| User Cache | **50ms** | **1** | Medium |
| Geohash Tiles | 200ms | 4-9 | High |
| Hybrid | **50ms initial** | 1-10 | High |

## Recommendation

**Start with User Cache (Option 2)** because:
1. Fastest possible load time (50ms)
2. Simplest to implement
3. Best user experience
4. Can add geohash tiles later for exploration

## Next Steps

1. **Immediate fix**: Load friend IDs on startup
2. **This week**: Implement user cache
3. **Future**: Add geohash tiles for exploration
