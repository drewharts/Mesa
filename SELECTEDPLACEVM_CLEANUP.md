# SelectedPlaceViewModel Cleanup Plan

**Current State:** 1,471 lines, ~70 properties/methods  
**Status:** Classic God Object with too many responsibilities

## 🗑️ DEAD CODE TO REMOVE (100% unused)

### 1. Comment Management (ENTIRE SECTION - ~250 lines)
**All removed since InlineCommentsView was deleted:**
- `placeReviewComments: [String: [Comment]]`
- `commentLoadingStates: [String: LoadingState]`
- `commentPhotos: [String: [UIImage]]`
- `reviewCommentCounts: [String: Int]`
- `loadCommentsForReview(reviewId:)`
- `addComment(reviewId:text:images:userId:userFirstName:userLastName:profilePhotoUrl:)`
- `loadCommentPhotos(for:)`
- `comments(for:)`
- `commentLoadingState(for:)`
- `commentPhotos(for:)`
- `commentCount(for:)`
- `loadCommentCountForReview(placeId:reviewId:)`
- `loadMoreComments(placeId:reviewId:limit:)`

**Lines to delete:** 184-186, 1025-1175, 1336-1369

### 2. Like Management (Empty Implementation - ~25 lines)
**TODO stubs that do nothing:**
- `likedReviews: Set<String>` - Cleared on place change but never populated
- `checkLikeStatuses(userId:)` - Old Firebase code, not used with Supabase
- `likeReview(_:userId:)` - Empty TODO
- `isReviewLiked(_:)` - Returns from empty set

**Usage:** PlaceReviewsViewModel has its own like management now
**Lines to delete:** 179-180, 1002-1023, 1225-1226, 1328-1334

### 3. Potentially Unused Helpers
**Need to verify usage:**
- `getReview(by:)` - Line 935-943
- `formattedTimestamp(for:)` - Line 1240-1257
- `setDetailPlaceViewModel(_:)` - Line 36-38
- `loadMorePhotosForAbout(placeId:)` - Line 901-905 (just calls loadMorePhotos)
- `loadMoreReviewPhotos(for:allImageUrls:)` - Line 706-739

## ✅ ALREADY EXTRACTED (Keep public accessors for now)

### Recently Moved to Child ViewModels:
1. **PlacePhotosViewModel** - Photo loading logic extracted
2. **TravelTimeViewModel** - Travel time logic extracted  
3. **TikTokVideosViewModel** - TikTok video logic extracted
4. **PlaceReviewsViewModel** - Review display logic extracted

**Public accessors still needed:**
- `reviews`, `tiktokVideos`, `photos`, `photoLoadingState`
- `photos(for:)`, `photoLoadingState(for:)`
- `profilePhoto(forUserId:)`, `profilePhotoLoadingState(forUserId:)`
- `reviewLoadingState(forPlaceId:)`
- `reviewPhotosForAbout(forPlaceId:)`, `reviewPhotosForAboutLoadingState(forPlaceId:)`
- `externalReviewPhotos`, `externalReviewPhotoLoadingState`, `externalReviewPhotosFullyLoaded`
- `allPhotosLoadedForCurrentPlace`
- `loadMorePhotos()`, `loadInitialExternalReviewPhotos()`, `loadMoreExternalReviewPhotosIfNeeded(currentIndex:)`
- `reloadReviewPhotos(for:)`

## 🎯 NEXT PHASE: Extract Remaining Responsibilities

### After Dead Code Removal:
1. **RestaurantInfoViewModel** - Restaurant type, open hours calculation
2. **PlaceCreationViewModel** - `createNewPlace` logic
3. **PlaceDetailCoordinator** - Orchestrate all the child ViewModels

## 📊 Results

### ✅ Phase 1: Dead Code Removal COMPLETE

**Before:**
- 1,471 lines
- ~70 properties/methods
- 8+ responsibilities

**After Dead Code Removal:** ✅ DONE
- 1,261 lines (saved 210 lines)
- 60 properties/methods
- 6 responsibilities

**Removed:**
- All comment management code (~170 lines)
- `setDetailPlaceViewModel()` method
- `loadMorePhotosForAbout()` method
- Comment-related properties (4 dictionaries)
- Comment-related method calls from review loading

### 🎯 Phase 2: Next Refactoring Steps

**After Full Refactoring (TODO):**
- ~400-500 lines (coordinator only)
- ~20 properties/methods
- 1 responsibility (coordinate place selection & detail fetching)

**Extract into new ViewModels:**
1. **RestaurantInfoViewModel** - Restaurant type, open hours
2. **PlaceCreationViewModel** - `createNewPlace` logic  
3. **PlaceDetailCoordinator** - Orchestrate all child ViewModels

**Consolidate with existing:**
- Move photo management methods to PlacePhotosViewModel
- Move review management methods to PlaceReviewsViewModel

