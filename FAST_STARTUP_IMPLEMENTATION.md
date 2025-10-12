# 🚀 Fast Startup Implementation Plan

## Current Problem (5-6 seconds)
DataManager loads EVERYTHING on startup:
- All user's places (50+ documents)
- All favorites (10+ documents)  
- All lists + places in them (100+ documents)
- All reviewed places (50+ documents)
- All friends' favorites/lists (1000+ documents!)

**Total: 1000-2000+ Firestore reads before map shows!**

## Solution: Load ONLY What's Visible

### New Startup Flow (< 1 second):
1. Load user profile (1 doc) 
2. Load place IDs only (not full documents)
3. Show map immediately
4. Load viewport places (50-100 docs max)
5. Background: Load rest as needed

### Implementation Steps:

#### Step 1: Create Minimal DataManager
```swift
func initializeMinimalData(userId: String) async {
    // Only load profile and IDs
    async let profile = loadProfileData(userId)
    async let placeIds = loadPlaceIdsOnly(userId) 
    
    await (profile, placeIds)
    // Map shows NOW - under 0.5s!
}
```

#### Step 2: Skip Heavy Operations
- DON'T load all myPlaces documents
- DON'T load all favorites documents
- DON'T load all list places
- DON'T load friends' places

#### Step 3: Load Viewport Only
- Map loads ~50 places in viewport
- Other places load when panned

## Expected Results:
- **Before**: 5-6 seconds (1000+ docs)
- **After**: < 1 second (50-100 docs)
- **95% faster!**
