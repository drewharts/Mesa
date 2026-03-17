import Foundation

/// Legacy ReviewService - now delegates all calls to SupabasePostService
/// This wrapper exists for backward compatibility with existing code
/// New code should use PostService directly
class ReviewService: ObservableObject {
    nonisolated(unsafe) static let shared = ReviewService()
    private let supabasePostService = SupabasePostService.shared
    
    private init() {}

    // MARK: - Like Methods (still use review_likes table)
    
    func likeReview(userId: String, placeId: String, reviewId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Task { @MainActor in
            supabasePostService.likePost(postId: reviewId, userId: userId) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
    }

    func unlikeReview(userId: String, placeId: String, reviewId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Task { @MainActor in
            supabasePostService.unlikePost(postId: reviewId, userId: userId) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
    }
    
    func hasUserLikedReview(userId: String, placeId: String, reviewId: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(false))
    }
    
    func toggleReviewLike(userId: String, placeId: String, reviewId: String, currentlyLiked: Bool, completion: @escaping (Result<Bool, Error>) -> Void) {
        if currentlyLiked {
            unlikeReview(userId: userId, placeId: placeId, reviewId: reviewId) { result in
                switch result {
                case .success:
                    completion(.success(false))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        } else {
            likeReview(userId: userId, placeId: placeId, reviewId: reviewId) { result in
                switch result {
                case .success:
                    completion(.success(true))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Delete
    
    func deleteReview(reviewId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Task { @MainActor in
            supabasePostService.deletePost(postId: reviewId) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
    }
    
    // MARK: - External Review Media
    
    func fetchExternalReviewMedia(placeId: String, reviewOffset: Int, reviewLimit: Int) async throws -> (urls: [String], nextReviewOffset: Int, hasMore: Bool) {
        return try await supabasePostService.fetchExternalReviewMedia(placeId: placeId, reviewOffset: reviewOffset, reviewLimit: reviewLimit)
    }
}
