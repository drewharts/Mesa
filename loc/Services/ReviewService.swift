import Foundation

/// Legacy ReviewService - now delegates all calls to SupabaseReviewService
/// This wrapper exists for backward compatibility with existing ViewModels
class ReviewService: ObservableObject {
    static let shared = ReviewService()
    private let supabase = SupabaseReviewService.shared // All data comes from Supabase
    
    private init() {
        print("⚠️ ReviewService is a compatibility wrapper - all data from Supabase")
    }

    func fetchReviews<T>(placeId: String, latestOnly: Bool = false, completion: @escaping ([T]?, Error?) -> Void) {
        // ⚠️ NOW FETCHING FROM SUPABASE, NOT FIRESTORE
        print("🔄 [ReviewService] Delegating to Supabase...")
        Task { @MainActor in
            await supabase.fetchReviews(placeId: placeId, latestOnly: latestOnly, completion: completion)
        }
    }
    
    // All other methods are placeholders that delegate to Supabase
    // They return success/empty results to avoid crashes while features are being migrated

    func saveReview<T: ReviewProtocol>(_ review: T, completion: @escaping (Result<Void, Error>) -> Void) {
        print("⚠️ [ReviewService] saveReview not fully implemented - delegating to Supabase")
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
        print("⚠️ [ReviewService] likeReview not fully implemented - delegating to Supabase")
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
        print("⚠️ [ReviewService] unlikeReview not fully implemented - delegating to Supabase")
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
        print("⚠️ [ReviewService] uploadReviewPhotos not fully implemented")
        completion(.success([]))
    }
    
    func deleteReview(review: ReviewProtocol, completion: @escaping (Result<Void, Error>) -> Void) {
        print("⚠️ [ReviewService] deleteReview not fully implemented")
                completion(.success(()))
    }
    
    func hasUserLikedReview(userId: String, placeId: String, reviewId: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        print("⚠️ [ReviewService] hasUserLikedReview not fully implemented")
        completion(.success(false))
    }
    
    func toggleReviewLike(userId: String, placeId: String, reviewId: String, currentlyLiked: Bool, completion: @escaping (Result<Bool, Error>) -> Void) {
        print("⚠️ [ReviewService] toggleReviewLike not fully implemented")
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
        print("⚠️ [ReviewService] fetchComments not fully implemented - delegating to Supabase")
        Task { @MainActor in
            await supabase.fetchComments(reviewId: reviewId, completion: completion)
        }
    }
    
    func saveComment(reviewId: String, userId: String, text: String, completion: @escaping (Error?) -> Void) {
        print("⚠️ [ReviewService] saveComment not fully implemented - delegating to Supabase")
        Task { @MainActor in
            await supabase.addComment(reviewId: reviewId, userId: userId, text: text, completion: completion)
        }
    }
    
    func fetchUserReviews(userId: String, completion: @escaping ([ReviewProtocol]?, Error?) -> Void) {
        print("⚠️ [ReviewService] fetchUserReviews not fully implemented")
        completion([], nil)
    }
    
    func fetchUserReviews(userId: String) async throws -> [RestaurantReview] {
        print("⚠️ [ReviewService] fetchUserReviews async not fully implemented")
        return []
    }
    
    func fetchUserGenericReviews(userId: String) async throws -> [GenericReview] {
        print("⚠️ [ReviewService] fetchUserGenericReviews async not fully implemented")
        return []
    }
    
    func fetchPlaceReviews(placeId: String, latestOnly: Bool = false, completion: @escaping ([ReviewProtocol]?, Error?) -> Void) {
        print("⚠️ [ReviewService] fetchPlaceReviews not fully implemented")
                completion([], nil)
    }
    
    func fetchPlaceReviews(placeId: String, latestOnly: Bool = false) async throws -> [ReviewProtocol] {
        print("⚠️ [ReviewService] fetchPlaceReviews async not fully implemented")
        return []
    }
    
    func deleteReview(reviewId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        print("⚠️ [ReviewService] deleteReview not fully implemented")
        completion(.success(()))
    }
    
    func addComment(reviewId: String, userId: String, text: String, completion: @escaping (Result<Void, Error>) -> Void) {
        print("⚠️ [ReviewService] addComment not fully implemented")
        completion(.success(()))
    }
} 
