-- ============================================================================
-- FETCH REVIEWS WITH TIKTOKS SQL FUNCTION
-- ============================================================================
-- This function fetches all reviews for a place AND any associated TikTok videos
-- in a SINGLE optimized query. This is called when a user taps on a place annotation.
--
-- Architecture:
-- 1. Backend (Mesa) → Place details + external ratings
-- 2. Supabase (this function) → Reviews + TikToks
--
-- This is more efficient than fetching TikToks separately with place details.
-- ============================================================================

-- Drop existing function versions to avoid ambiguity
DROP FUNCTION IF EXISTS get_place_reviews_with_tiktoks(UUID);
DROP FUNCTION IF EXISTS get_place_reviews_with_tiktoks(TEXT);
DROP FUNCTION IF EXISTS get_place_reviews_with_tiktoks(TEXT, INTEGER, INTEGER);

-- Create the function with TEXT parameter and pagination support
CREATE OR REPLACE FUNCTION get_place_reviews_with_tiktoks(
    p_place_id TEXT,
    p_limit INTEGER DEFAULT 4,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    -- Reviews data (note: IDs are TEXT, not UUID in the reviews table)
    review_id TEXT,
    review_user_id TEXT,
    review_text TEXT,
    review_images TEXT[],
    review_timestamp TIMESTAMP,
    review_type TEXT,
    review_likes INTEGER,
    
    -- User information (CURRENT data from users table, not denormalized)
    user_first_name TEXT,
    user_last_name TEXT,
    user_profile_photo_url TEXT,
    
    -- TikTok videos (as JSONB array)
    tiktok_videos JSONB[]
) AS $$
BEGIN
    RETURN QUERY
    WITH place_tiktoks AS (
        -- Get all TikTok videos for this place (if any)
        SELECT 
            ep.place_id,
            ep.tiktok_videos
        FROM external_places ep
        WHERE ep.place_id = p_place_id
        LIMIT 1
    )
    SELECT 
        -- Reviews columns
        r.id AS review_id,
        r.user_id AS review_user_id,
        r.review_text,
        r.images AS review_images,
        r.timestamp AS review_timestamp,
        r.type AS review_type,
        r.likes AS review_likes,
        
        -- User information (CURRENT from users table via JOIN)
        u.first_name AS user_first_name,
        u.last_name AS user_last_name,
        u.profile_photo_url AS user_profile_photo_url,
        
        -- TikTok videos
        COALESCE(pt.tiktok_videos, '{}'::jsonb[]) AS tiktok_videos
    FROM reviews r
    INNER JOIN users u ON r.user_id = u.id  -- JOIN with users table for current data
    LEFT JOIN place_tiktoks pt ON pt.place_id = r.place_id
    WHERE r.place_id = p_place_id
    ORDER BY r.timestamp DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- USAGE EXAMPLE
-- ============================================================================
-- SELECT * FROM get_place_reviews_with_tiktoks('your-place-uuid-here');
--
-- Expected result:
-- - Multiple rows (one per review)
-- - Each row contains review data + the TikTok videos array
-- - If no TikToks exist, tiktok_videos will be an empty array []
-- - If no reviews exist, returns 0 rows (but you can still check for TikToks separately)
-- ============================================================================

-- ============================================================================
-- SWIFT CODE UPDATES
-- ============================================================================

/*
UPDATE: loc/Services/SupabaseReviewService.swift

Add a new struct to handle the combined response:
*/

/*
struct ReviewWithTikToksRecord: Codable {
    let review_id: String
    let review_user_id: String
    let review_text: String
    let review_images: [String]?
    let review_rating: Double?
    let review_timestamp: String
    let review_type: String?
    let review_price_paid: Double?
    let review_created_at: String
    let review_updated_at: String
    let tiktok_videos: AnyCodable? // JSONB array of TikTok videos
}
*/

/*
UPDATE: loc/Services/SupabaseReviewService.swift - fetchPlaceReviews() function

Replace the existing fetchPlaceReviews function (around line 195) with:
*/

/*
func fetchPlaceReviews(placeId: String, latestOnly: Bool = false) async throws -> ([ReviewProtocol], [TikTokVideo]) {
    // Call the new SQL function that returns reviews + TikToks
    let response: [ReviewWithTikToksRecord] = try await supabase.client
        .rpc("get_place_reviews_with_tiktoks", params: ["p_place_id": placeId])
        .execute()
        .value
    
    // Extract TikToks from the first row (they're the same for all rows)
    var tiktokVideos: [TikTokVideo] = []
    if let firstRecord = response.first,
       let tiktokData = firstRecord.tiktok_videos?.value as? [[String: Any]] {
        tiktokVideos = tiktokData.compactMap { dict -> TikTokVideo? in
            guard let videoId = dict["video_id"] as? String,
                  let videoUrl = dict["video_url"] as? String else {
                return nil
            }
            return TikTokVideo(
                id: videoId,
                url: videoUrl,
                thumbnailUrl: dict["thumbnail_url"] as? String,
                title: dict["title"] as? String,
                authorName: dict["author_name"] as? String,
                authorUsername: dict["author_username"] as? String,
                likeCount: dict["like_count"] as? Int,
                commentCount: dict["comment_count"] as? Int,
                shareCount: dict["share_count"] as? Int,
                viewCount: dict["view_count"] as? Int,
                duration: dict["duration"] as? Int,
                createdAt: dict["created_at"] as? String
            )
        }
    }
    
    // Convert records to ReviewProtocol objects
    let reviews: [ReviewProtocol] = response.compactMap { record -> ReviewProtocol? in
        guard let reviewId = UUID(uuidString: record.review_id),
              let userId = UUID(uuidString: record.review_user_id) else {
            return nil
        }
        
        // Parse timestamp
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = dateFormatter.date(from: record.review_timestamp) ?? Date()
        
        return Review(
            id: reviewId.uuidString,
            userId: userId.uuidString,
            placeId: placeId,
            text: record.review_text,
            images: record.review_images,
            rating: record.review_rating,
            timestamp: timestamp,
            type: record.review_type,
            pricePaid: record.review_price_paid
        )
    }
    
    // Apply latestOnly filter if needed
    if latestOnly && !reviews.isEmpty {
        return ([reviews[0]], tiktokVideos)
    }
    
    return (reviews, tiktokVideos)
}
*/

/*
UPDATE: loc/Services/ReviewService.swift

Update the compatibility wrapper to handle the tuple return:
*/

/*
func fetchPlaceReviews(placeId: String, latestOnly: Bool = false) async throws -> ([ReviewProtocol], [TikTokVideo]) {
    return try await supabase.fetchPlaceReviews(placeId: placeId, latestOnly: latestOnly)
}
*/

/*
UPDATE: loc/ViewModels/SelectedPlaceViewModel.swift

Update loadReviewsWithUserId() around line 431 to also store TikToks:
*/

/*
// Add this property to the class
@Published private var placeTikToks: [String: [TikTokVideo]] = [:] // Cache TikToks by placeId

// Update the loadReviewsWithUserId function
private func loadReviewsWithUserId(placeId: String, currentUserId: String) {
    // Fetch reviews AND TikToks for the specific place
    Task {
        do {
            let (reviews, tiktoks) = try await reviewService.fetchPlaceReviews(placeId: placeId, latestOnly: false)
            
            await MainActor.run {
                self.placeReviews[placeId] = reviews
                self.placeTikToks[placeId] = tiktoks // Store TikToks
                
                reviews.forEach { review in
                    self.loadReviewPhotos(for: review)
                    self.loadProfilePhoto(for: review)
                    self.loadCommentCountForReview(placeId: placeId, reviewId: review.id)
                }
                self.reviewLoadingStates[placeId] = .loaded
                self.updateCurrentPlaceFullyLoaded()
                print("✅ [SelectedPlaceViewModel] Loaded \(reviews.count) reviews and \(tiktoks.count) TikToks for place \(placeId)")
            }
        } catch {
            await MainActor.run {
                print("❌ [SelectedPlaceViewModel] Error fetching reviews/TikToks for place \(placeId): \(error.localizedDescription)")
                self.reviewLoadingStates[placeId] = .error(error)
                self.placeReviews[placeId] = []
                self.placeTikToks[placeId] = []
                self.updateCurrentPlaceFullyLoaded()
            }
        }
    }
}

// Add a getter for TikToks
var tiktokVideos: [TikTokVideo] {
    guard let placeId = selectedPlace?.id.uuidString else { return [] }
    return placeTikToks[placeId] ?? []
}
*/

-- ============================================================================
-- PERFORMANCE NOTES
-- ============================================================================
-- ✅ Single query fetches both reviews AND TikToks
-- ✅ TikTok data is only returned once (not duplicated for each review)
-- ✅ No N+1 query problem
-- ✅ Efficient LEFT JOIN ensures we get reviews even if no TikToks exist
-- ✅ COALESCE ensures we always return an array (never NULL)
-- ============================================================================

-- ============================================================================
-- ALTERNATIVE: Fetch TikToks separately if no reviews exist
-- ============================================================================
-- If you need to fetch TikToks even when there are no reviews, create this helper:

DROP FUNCTION IF EXISTS get_place_tiktoks(UUID);

CREATE OR REPLACE FUNCTION get_place_tiktoks(p_place_id UUID)
RETURNS TABLE (tiktok_videos JSONB) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE(ep.tiktok_videos, '[]'::jsonb) AS tiktok_videos
    FROM external_places ep
    WHERE ep.place_id = p_place_id
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Usage: SELECT * FROM get_place_tiktoks('your-place-uuid-here');
-- This is useful if you want to show TikToks on a place that has no reviews yet.

