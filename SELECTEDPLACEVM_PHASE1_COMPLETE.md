# SelectedPlaceViewModel Phase 1: Dead Code Removal ✅ COMPLETE

## 🎉 Summary

Successfully removed **210 lines of dead code** from SelectedPlaceViewModel!

### Before & After

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| **Lines** | 1,471 | 1,261 | -210 lines (14%) |
| **Properties/Methods** | ~70 | 60 | -10 items |
| **Responsibilities** | 8+ | 6 | -2 |

## 🗑️ What Was Removed

### 1. Comment Management System (~170 lines)
**Reason:** `InlineCommentsView` and `InlineCommentView` were deleted in previous refactoring

**Removed Properties:**
- `placeReviewComments: [String: [Comment]]` 
- `commentLoadingStates: [String: LoadingState]`
- `commentPhotos: [String: [UIImage]]`
- `reviewCommentCounts: [String: Int]`

**Removed Methods:**
- `loadCommentsForReview(reviewId:)` 
- `addComment(reviewId:text:images:userId:...)`
- `loadCommentPhotos(for:)`
- `comments(for:)` - Public accessor
- `commentLoadingState(for:)` - Public accessor
- `commentPhotos(for:)` - Public accessor
- `commentCount(for:)` - Public accessor
- `loadCommentCountForReview(placeId:reviewId:)`
- `loadMoreComments(placeId:reviewId:limit:)`

**Cleanup:**
- Removed `loadCommentCountForReview` call from `loadReviews` method
- Removed comment cleanup from `deleteReview` method

### 2. Unused Helper Methods
- `setDetailPlaceViewModel(_:)` - Never called
- `loadMorePhotosForAbout(placeId:)` - Never called, redundant with `loadMorePhotos()`

### 3. Comment-Related Dictionary Entries
Removed references in `deleteReview`:
- `placeReviewComments.removeValue(forKey:)`
- `commentLoadingStates.removeValue(forKey:)`
- `reviewCommentCounts.removeValue(forKey:)`

## ✅ Verified Safe Deletions

All deletions were verified by:
1. ✅ Searching codebase for usage (`grep` across all files)
2. ✅ No view files reference comment methods
3. ✅ No linter errors after removal
4. ✅ Comment UI was already deleted in previous refactor

## 📋 What Remains (6 Core Responsibilities)

1. **Place Selection & Detail Fetching** ⭐ (Core responsibility)
2. **Photo Loading & Caching** (Many methods - candidate for extraction)
3. **Review Loading & Management** (Some methods - candidate for extraction)
4. **Restaurant Info** (Type calculation, open hours)
5. **Place Creation** (Large method - candidate for extraction)
6. **Like Management** (Stub implementation - needs work or removal)

## 🎯 Next Steps: Phase 2 Refactoring

### Immediate Candidates for Extraction:

#### 1. Move to `PlacePhotosViewModel` (already exists!)
**Photo loading methods that should move:**
- `getPlacePhotos(for:loadMore:)` 
- `loadReviewPhotosForAbout(for:)`
- `loadReviewPhotos(for:)`
- `loadMorePhotos()`
- `loadMoreReviewPhotos(for:allImageUrls:)`
- `loadInitialExternalReviewPhotos()`
- `loadMoreExternalReviewPhotosIfNeeded(currentIndex:)`
- `loadExternalReviewPhotos(for:reset:)`
- `loadExternalReviewPhotosInternal(...)`
- `extendExternalReviewURLs(...)`
- `loadExternalReviewImages(from:)`
- `externalReviewPaginationState(for:reset:)`
- `updateExternalReviewPaginationState(...)`
- `resetPhotoLoading()`

**Keep in SelectedPlaceViewModel:** Only public accessors as delegation to child VM

#### 2. Create `PlaceCreationViewModel`
**Extract:**
- `createNewPlace(...)` (large method, 84 lines)
- Can also handle `navigateToMapAndSelectPlace` logic

#### 3. Create `RestaurantInfoViewModel` 
**Extract:**
- `isRestaurantOpenNow(_:)` 
- `calculateAndStoreRestaurantType(for:)`
- `getRestaurantType(for:)` accessor
- `restaurantTypes` dictionary

#### 4. Consolidate Review Methods with `PlaceReviewsViewModel`
**Move:**
- `addReview(_:)`
- `deleteReview(reviewId:completion:)`
- `formattedTimestamp(for:)` 
- `getReview(by:)` 

#### 5. Clean Up or Remove Like Management
**Either:**
- **Option A:** Implement properly in `PlaceReviewsViewModel`
- **Option B:** Remove entirely (`likeReview`, `isReviewLiked`, `checkLikeStatuses`, `likedReviews`)

### Target After Phase 2:
- **400-500 lines** (coordinator only)
- **~20 properties/methods**
- **1 core responsibility:** Place selection & coordination

## 🏗️ Architecture Vision

```
SelectedPlaceViewModel (Coordinator - 400 lines)
├── selectedPlace management
├── detail fetching coordination
└── Child VM coordination
    ├── PlacePhotosViewModel (all photo logic)
    ├── PlaceReviewsViewModel (all review logic)
    ├── RestaurantInfoViewModel (restaurant-specific logic)
    └── PlaceCreationViewModel (place creation flow)
```

## 💡 Key Learnings

1. **Dead code accumulates fast** - Removing UI doesn't automatically remove ViewModel code
2. **Always verify usage** - Use `grep` across entire codebase before deleting
3. **Document as you go** - Makes future refactoring easier
4. **Incremental is safer** - 210 lines at a time, not 1000

---

**Status:** ✅ Phase 1 Complete - Ready for Phase 2  
**Next:** Extract photo logic to `PlacePhotosViewModel` (biggest win, ~300+ lines)

