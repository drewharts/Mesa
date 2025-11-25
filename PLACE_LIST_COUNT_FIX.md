# Place List Count Fix - Staff Engineer Solution

## Problems

### Problem 1: Count Resets to 1
When adding a place to a list via `PlaceListSelectionViewModel`, the count was resetting to 1 instead of incrementing from the actual count.

**Root Cause:**
- `PlaceListSelectionViewModel` owns its own `lists` array (fetched by proximity)
- When toggling a place, it delegated to `ProfileViewModel.addPlaceToLightweightList()`
- `ProfileViewModel` tried to infer the count from its own `lightweightPlaceLists` array
- But that list didn't exist in ProfileViewModel's state (it was only in PlaceListSelectionViewModel)
- Fallback logic returned 0, resulting in count = 0 + 1 = 1

### Problem 2: Remove + Re-add Doesn't Update Count
After initial fix, removing a place and adding it back didn't update the count.

**Root Cause:**
- PlaceListSelectionViewModel calculated the new count AND updated local state
- But passed the OLD `list.place_count` parameter to ProfileViewModel
- ProfileViewModel then did its OWN calculation on the stale count
- Result: **double calculation with stale data** → incorrect counts

### Problem 3: First Toggle Doesn't Work (Need to Toggle Twice)
After second fix, the first toggle from TikTok list or review list didn't update the count correctly, but second toggle worked.

**Root Cause - Classic SwiftUI Struct Capture Bug:**
- `LightweightPlaceList` is a **struct** (value type)
- SwiftUI's `ForEach` closure captures the `list` parameter by value
- When `updateLocalListCount()` updates the array, it creates a new struct instance
- But the closure **still holds the old captured snapshot**
- First toggle uses stale `list.place_count`, second toggle re-renders with fresh data
- This is a textbook value-type-in-closure issue

## Solution - Following Single Responsibility Principle

### Key Principle
**State owner does the calculation, state receiver stores the result. No double-calculation, no stale data.**

### Implementation

#### 1. ProfileViewModel (State Receiver)
**File**: `loc/ViewModels/ProfileViewModel.swift`

Added optional `updatedCount` parameter to both methods:
- `addPlaceToLightweightList(listId:place:updatedCount:)`
- `removePlaceFromLightweightList(listId:place:updatedCount:)`

```swift
if let finalCount = updatedCount {
    // Caller owns state and has already done the math - just store it
    lightweightPlaceListCounts[listId] = finalCount
} else {
    // Legacy path: we own the state, so we do the math
    let startingCount = lightweightPlaceListCounts[listId]
        ?? lightweightPlaceLists.first(where: { $0.list_id == listId })?.place_count
        ?? 0
    lightweightPlaceListCounts[listId] = startingCount + 1  // or -1 for remove
}
```

**Critical Design Decision**: 
- When `updatedCount` is provided → **store it directly** (no calculation)
- When `updatedCount` is nil → **calculate it ourselves** (legacy path)
- This prevents double-calculation and ensures single source of truth

#### 2. PlaceListSelectionViewModel (State Owner)
**File**: `loc/ViewModels/PlaceListSelectionViewModel.swift`

Added `updateLocalListCount()` method that:
1. Updates its own `lists` array with the new count
2. Creates a new `LightweightPlaceList` instance (struct is immutable)
3. Replaces the list in the array

Modified `toggle()` to:
1. **Look up current state from `lists` array** (not stale captured parameter)
2. **Calculate the new count from the fresh current state**
3. Update its own local state
4. **Pass the already-calculated count to ProfileViewModel (no further calculation needed)**
5. Both ViewModels stay synchronized

```swift
func toggle(place: DetailPlace, in list: LightweightPlaceList) {
    // CRITICAL FIX: Look up current state from our array (not the stale captured parameter)
    // Since LightweightPlaceList is a struct (value type), the parameter may be a stale snapshot
    // from when the closure was created. Always read from the source of truth: lists array.
    guard let currentList = lists.first(where: { $0.list_id == list.list_id }) else { return }
    
    let wasInList = isPlace(place, in: currentList)
    
    if wasInList {
        // Calculate new count from CURRENT state (not stale parameter)
        let newCount = max(0, currentList.place_count - 1)
        updateLocalListCount(listId: currentList.list_id, delta: -1)
        profile.removePlaceFromLightweightList(listId: currentList.list_id, place: place, updatedCount: newCount)
        placeMembership[currentList.list_id] = false
    } else {
        // Calculate new count from CURRENT state (not stale parameter)
        let newCount = currentList.place_count + 1
        updateLocalListCount(listId: currentList.list_id, delta: +1)
        profile.addPlaceToLightweightList(listId: currentList.list_id, place: place, updatedCount: newCount)
        placeMembership[currentList.list_id] = true
    }
}
```

## Why This is a Staff Engineer Solution

### 1. **Single Responsibility Principle (SRP)**
- **State owner does the calculation** (PlaceListSelectionViewModel)
- **State receiver stores the result** (ProfileViewModel)
- No double-calculation, no stale data, no confusion about who owns what
- Each ViewModel has a clear, single responsibility

### 2. **Explicit Over Implicit**
- Data flow is crystal clear: calculate → update local → pass final result
- **One calculation, one source of truth**
- No hidden dependencies or state inference across boundaries
- Easy to reason about and debug

### 3. **Prevents Common SwiftUI Anti-Patterns**
- ❌ **OLD**: Both ViewModels calculate → double calculation with stale data
- ✅ **NEW**: Owner calculates once, receiver stores → single source of truth
- ❌ **OLD**: Use captured struct parameter → stale data in closures
- ✅ **NEW**: Look up from source array → always fresh data
- Eliminates entire class of synchronization and value-capture bugs

### 4. **Backwards Compatible**
- Optional parameter with sensible default
- Existing calls continue to work without changes
- Legacy code paths remain functional (ProfileViewModel does its own math when needed)

### 5. **Minimal Surface Area**
- Small, focused change
- Only two files modified
- No architectural overhaul required

### 6. **Testable**
- Each ViewModel can be tested independently
- Clear contract: "If you pass updatedCount, I store it. If not, I calculate it."
- No complex mocking of cross-ViewModel state

## Results
✅ Counts increment correctly (e.g., 5 → 6 instead of 5 → 1)
✅ Remove + re-add works correctly (5 → 4 → 5, not 5 → 4 → 5 → 6)
✅ **First toggle works immediately** (no need to toggle twice)
✅ Works correctly from TikTok list and review list navigation
✅ Both ViewModels stay synchronized
✅ Clean separation of concerns
✅ No linter errors
✅ Backwards compatible
✅ Single source of truth for calculations
✅ Prevents struct capture bugs in closures

## Files Changed
1. `loc/ViewModels/ProfileViewModel.swift`
   - Renamed parameter from `currentCount` to `updatedCount` (semantic clarity)
   - Changed from "infer + calculate" to "store final result OR calculate if legacy"
   - When `updatedCount` is provided → store it directly (no math)
   - When `updatedCount` is nil → calculate ourselves (legacy path)

2. `loc/ViewModels/PlaceListSelectionViewModel.swift`
   - Added `updateLocalListCount()` helper
   - Updated `toggle()` to calculate new count FIRST from current state
   - Passes final calculated count to ProfileViewModel (no further calculation)

## Key Insights

### Issue 1 & 2: Architecture
**The bug was caused by "who does the math" being unclear, causing double-calculation with stale data.**

**The fix makes it explicit: State owner calculates, state receiver stores.**

### Issue 3: SwiftUI Value Types
**Value types (structs) captured in closures become stale snapshots when the original is mutated.**

**The fix: Always read from the authoritative source array, never trust captured parameters.**

This is a critical lesson for working with structs in SwiftUI - the convenience of value semantics comes with the cost of closure capture bugs. Always ask: "Is this parameter a potentially stale snapshot?"

