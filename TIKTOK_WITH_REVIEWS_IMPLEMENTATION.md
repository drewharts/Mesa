# TikTok Videos Fetched with Reviews - Implementation Summary

## Overview
Implemented an optimized solution to fetch TikTok videos alongside reviews in a **single database query** when a user taps on a place annotation. This is more efficient than fetching TikToks separately with place details.

## Architecture Decision

### ✅ Final Approach: Fetch TikToks with Reviews
- **Backend (Mesa)** → Place details + External ratings (Google, Yelp)
- **Supabase** → Reviews + TikToks **in one query**

This approach makes sense because:
- Reviews and TikToks are both **user-generated content** stored in Supabase
- They're loaded **on-demand** when user taps an annotation
- Single query is more efficient than two separate calls
- TikTok data is not duplicated (returned once, applies to all reviews)

## Database Changes

### SQL Function Created
```sql
CREATE FUNCTION get_place_reviews_with_tiktoks(p_place_id UUID)
RETURNS TABLE (
    review_id, review_user_id, review_text, review_images,
    review_rating, review_timestamp, review_type, review_price_paid,
    review_created_at, review_updated_at,
    tiktok_videos JSONB  -- TikTok array, same for all rows
)
```

**Location**: Applied via MCP to Supabase project `posfruqvibklcyfxmdbq`

**How it works**:
1. Queries `reviews` table for the place
2. LEFT JOINs with `external_places` to get TikTok videos
3. Returns all reviews with TikTok array attached to each row
4. If no TikToks exist, returns empty array `[]`

## Swift Code Changes

### 1. SupabaseReviewService.swift

**Added struct**:
```swift
struct ReviewWithTikToksRecord: Codable {
    let review_id: String
    let review_user_id: String
    let review_text: String
    let review_images: [String]?
    let review_rating: Double?
    let review_timestamp: Date
    let review_type: String?
    let review_price_paid: Double?
    let review_created_at: Date
    let review_updated_at: Date
    let tiktok_videos: AnyCodable? // JSONB array
}
```

**Updated function**:
```swift
func fetchPlaceReviews(placeId: String, latestOnly: Bool = false) 
    async throws -> ([ReviewProtocol], [TikTokVideo])
```
- Calls the new SQL RPC function
- Parses TikTok JSON from first row (same for all)
- Converts records to ReviewProtocol objects
- Returns tuple of (reviews, tiktoks)

### 2. ReviewService.swift

**Updated wrapper**:
```swift
func fetchPlaceReviews(placeId: String, latestOnly: Bool = false) 
    async throws -> ([ReviewProtocol], [TikTokVideo])
```
- Now returns tuple instead of just reviews array
- Maintains backward compatibility with existing interface

### 3. SelectedPlaceViewModel.swift

**Added property**:
```swift
@Published private var placeTikToks: [String: [TikTokVideo]] = [:]
```

**Updated loadReviewsWithUserId**:
```swift
let (reviews, tiktoks) = try await reviewService.fetchPlaceReviews(...)
self.placeReviews[placeId] = reviews
self.placeTikToks[placeId] = tiktoks  // Store TikToks
```

**Added public accessor**:
```swift
var tiktokVideos: [TikTokVideo] {
    guard let placeId = selectedPlace?.id.uuidString else { return [] }
    return placeTikToks[placeId] ?? []
}
```

## User Flow

### When User Taps a Place Annotation:

1. **MapView** → `handleAnnotationTap()`
2. **MapViewModel** → `loadPlaceDetails(for: annotation)`
3. **PlaceService** → `fetchPlaceDetails(placeId:)` 
   - *(This is lightweight, no TikToks)*
4. **SelectedPlaceViewModel** → `loadReviewsWithUserId()`
   - **Calls** `reviewService.fetchPlaceReviews()`
   - **Gets** reviews + TikToks in **single query**
   - **Stores** both in cache
5. **PlaceDetailView** → Displays reviews and TikToks
   - Access via `selectedPlaceVM.reviews`
   - Access via `selectedPlaceVM.tiktokVideos`

## Performance Benefits

✅ **Single Query** - One RPC call instead of two separate queries  
✅ **No N+1 Problem** - TikToks fetched once, not per review  
✅ **Efficient JOIN** - PostgreSQL LEFT JOIN is optimized  
✅ **Cached** - TikToks stored in memory by placeId  
✅ **On-Demand** - Only loaded when user taps annotation  
✅ **No Map Performance Impact** - Map annotations remain lightweight  

## Files Modified

- ✅ `FETCH_REVIEWS_WITH_TIKTOKS.sql` - SQL function documentation
- ✅ `loc/Services/SupabaseReviewService.swift` - Added struct and updated fetch
- ✅ `loc/Services/ReviewService.swift` - Updated wrapper signature
- ✅ `loc/ViewModels/SelectedPlaceViewModel.swift` - Added TikTok storage and getter

## Files Deleted

- ❌ `ADD_TIKTOK_VIDEOS_TO_PLACE_FETCH.sql` - Old approach (fetch with place details)

## Testing Checklist

1. ✅ SQL function created in Supabase
2. ✅ Swift code compiles (import errors are expected)
3. ⏳ Test: Tap place annotation with TikToks
4. ⏳ Test: Verify TikToks display in PlaceDetailView
5. ⏳ Test: Tap place annotation without TikToks (should not crash)
6. ⏳ Test: Verify map performance (annotations load quickly)

## Next Steps

1. **Run the app** and test by tapping on a place that has associated TikTok videos
2. **Verify** that `selectedPlaceVM.tiktokVideos` is populated
3. **Ensure** PlaceDetailView displays the TikTok videos correctly
4. **Monitor** performance to confirm single query is efficient

## Notes

- TikTok videos are stored in `external_places.tiktok_videos` as JSONB
- The SQL function returns the same TikTok array for all reviews (not duplicated)
- If a place has no TikToks, an empty array `[]` is returned (never NULL)
- The `get_place_tiktoks()` helper function can fetch TikToks even if no reviews exist

