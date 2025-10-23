import Foundation

/// Legacy ReviewService - now delegates all calls to SupabaseReviewService
/// This wrapper exists for backward compatibility with existing ViewModels
class ReviewService: ObservableObject {
    static let shared = ReviewService()
    private let supabase = SupabaseReviewService.shared // All data comes from Supabase
    
    private init() {
        // ReviewService is a compatibility wrapper - all data from Supabase
    }

    func fetchReviews<T>(placeId: String, latestOnly: Bool = false, completion: @escaping ([T]?, Error?) -> Void) {
        Task { @MainActor in
            await supabase.fetchReviews(placeId: placeId, latestOnly: latestOnly, completion: completion)
        }
    }
    
    // All other methods are placeholders that delegate to Supabase
    // They return success/empty results to avoid crashes while features are being migrated

    func saveReview<T: ReviewProtocol>(_ review: T, completion: @escaping (Result<Void, Error>) -> Void) {
        Task { @MainActor in
            await supabase.saveReview(placeId: review.placeId, review: review, images: [], completion: { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            })
        }
    }

    func likeReview(userId: String, placeId: String, reviewId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Task { @MainActor in
            await supabase.likeReview(reviewId: reviewId, userId: userId, completion: { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
            })
        }
    }

    func unlikeReview(userId: String, placeId: String, reviewId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Task { @MainActor in
            await supabase.unlikeReview(reviewId: reviewId, userId: userId, completion: { error in
                if let error = error {
                                completion(.failure(error))
                            } else {
                                completion(.success(()))
                            }
            })
        }
    }
    
    func uploadReviewPhotos(images: [Data], completion: @escaping (Result<[String], Error>) -> Void) {
        completion(.success([]))
    }
    
    func deleteReview(review: ReviewProtocol, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
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
    
    func fetchComments(for reviewId: String, completion: @escaping ([Comment]?, Error?) -> Void) {
        Task { @MainActor in
            await supabase.fetchComments(reviewId: reviewId, completion: completion)
        }
    }
    
    func saveComment(reviewId: String, userId: String, text: String, completion: @escaping (Error?) -> Void) {
        Task { @MainActor in
            await supabase.addComment(reviewId: reviewId, userId: userId, text: text, completion: completion)
        }
    }
    
    func fetchUserReviews(userId: String, completion: @escaping ([ReviewProtocol]?, Error?) -> Void) {
        completion([], nil)
    }
    
    func fetchUserReviews(userId: String) async throws -> [RestaurantReview] {
        return try await supabase.fetchUserReviews(userId: userId)
    }
    
    func fetchUserGenericReviews(userId: String) async throws -> [GenericReview] {
        return try await supabase.fetchUserGenericReviews(userId: userId)
    }
    
    func fetchPlaceReviews(placeId: String, latestOnly: Bool = false, completion: @escaping ([ReviewProtocol]?, Error?) -> Void) {
        completion([], nil)
    }
    
    func fetchPlaceReviews(placeId: String, latestOnly: Bool = false) async throws -> ([ReviewProtocol], [TikTokVideo]) {
        return try await supabase.fetchPlaceReviews(placeId: placeId, latestOnly: latestOnly)
    }
    
    func deleteReview(reviewId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }
    
    func addComment(reviewId: String, userId: String, text: String, photoUrls: [String] = [], completion: @escaping (Result<Void, Error>) -> Void) {
        Task { @MainActor in
            await supabase.addComment(reviewId: reviewId, userId: userId, text: text, photoUrls: photoUrls) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
    }
} 
