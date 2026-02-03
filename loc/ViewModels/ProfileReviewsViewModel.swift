//
//  ProfileReviewsViewModel.swift
//  loc
//
//  Extracted from ProfileViewModel for reviewed places management.
//

import SwiftUI

/// Manages reviewed places for the current user's profile.
@MainActor
class ProfileReviewsViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Loading state for initial load
    @Published var isLoadingReviewedPlaces: Bool = false

    /// Loading state for pagination
    @Published var isLoadingMoreReviews: Bool = false

    /// Whether more reviews can be loaded
    @Published var hasMoreReviews: Bool = true

    /// Lightweight reviewed places data for display
    @Published var lightweightReviewedPlaces: [LightweightPlace] = []

    /// Total count of reviewed places from database
    @Published var totalReviewedPlacesCount: Int = 0

    /// Cached set of place IDs the user has reviewed (for unvisited filtering)
    @Published var verifiedReviewedPlaceIds: Set<String> = []

    /// Loading state for verified IDs
    @Published var isLoadingVerifiedReviewedIds: Bool = false

    // MARK: - Callbacks for Cross-Cutting Concerns

    /// Called to update places dictionary
    var onPlacesUpdate: ((String, DetailPlace?) -> Void)?

    /// Called to fetch place image
    var onFetchPlaceImage: ((String) -> Void)?

    /// Called to update placeSavers
    var onPlaceSaversUpdate: ((String, String, Bool) -> Void)?

    /// Called to recalculate annotation places
    var onAnnotationPlacesRecalculate: (() -> Void)?

    /// Called to update place images
    var onPlaceImageUpdate: ((String, UIImage) -> Void)?

    /// Called to check if place image exists
    var hasPlaceImage: ((String) -> Bool)?

    // MARK: - Dependencies

    private let placeService: PlaceService
    private let postService: PostService

    private let userService: UserService
    private weak var userSession: UserSession?

    // MARK: - Private State

    private var hasAttemptedInitialReviewsLoad: Bool = false
    private let reviewsPerPage: Int = 8

    // MARK: - Initialization

    /// Initializes the reviews view model with required dependencies.
    init(userService: UserService, userSession: UserSession, placeService: PlaceService, postService: PostService) {
        self.userService = userService
        self.userSession = userSession
        self.placeService = placeService
        self.postService = postService
    }

    // MARK: - Computed Properties

    /// Get the count of loaded reviewed places.
    var reviewedPlacesCount: Int {
        return lightweightReviewedPlaces.count
    }

    // MARK: - Public Methods

    /// Loads initial reviewed places (entry point).
    func loadMyReviewedPlacesWithPagination() async {
        guard let userId = userSession?.currentUserId else {
            print("⚠️ [ProfileReviewsViewModel] Cannot load reviewed places: no user ID")
            return
        }

        // Don't reload if already loading, if we have data, or if we already attempted
        guard !isLoadingReviewedPlaces && lightweightReviewedPlaces.isEmpty && !hasAttemptedInitialReviewsLoad else {
            return
        }

        await loadInitialReviewedPlaces()
    }

    /// Loads more reviewed places (pagination).
    func loadMoreMyReviews() async {
        guard let userId = userSession?.currentUserId else {
            print("⚠️ [ProfileReviewsViewModel] Cannot load more reviewed places: no user ID")
            return
        }

        // Guard: prevent multiple simultaneous loads
        guard !isLoadingMoreReviews && hasMoreReviews else {
            return
        }

        let offset = lightweightReviewedPlaces.count

        isLoadingMoreReviews = true

        defer {
            isLoadingMoreReviews = false
        }

        do {
            let lightweightPlaces = try await userService.fetchUserReviewedPlaces(userId: userId, limit: reviewsPerPage, offset: offset)

            // Deduplicate to prevent SwiftUI rendering issues
            let existingIds = Set(lightweightReviewedPlaces.map { $0.id })
            let newUniquePlaces = lightweightPlaces.filter { !existingIds.contains($0.id) }

            if !newUniquePlaces.isEmpty {
                lightweightReviewedPlaces.append(contentsOf: newUniquePlaces)
                let duplicateCount = lightweightPlaces.count - newUniquePlaces.count
                if duplicateCount > 0 {
                    print("⚠️ [ProfileReviewsViewModel] Filtered \(duplicateCount) duplicate reviewed places")
                }
            } else if !lightweightPlaces.isEmpty {
                print("⚠️ [ProfileReviewsViewModel] All \(lightweightPlaces.count) reviewed places were duplicates")
            }

            hasMoreReviews = !lightweightPlaces.isEmpty && lightweightPlaces.count >= reviewsPerPage

            // Load full place details for display (non-blocking)
            if !newUniquePlaces.isEmpty {
                Task {
                    await loadPlaceDetailsForReviews(newUniquePlaces, userId: userId)
                }
            }
        } catch {
            print("❌ [ProfileReviewsViewModel] Error loading more reviewed places: \(error.localizedDescription)")
            hasMoreReviews = false
        }
    }

    /// Resets reviewed places pagination state.
    func resetMyReviewedPlacesPagination() {
        isLoadingReviewedPlaces = false
        isLoadingMoreReviews = false
        hasMoreReviews = true
        lightweightReviewedPlaces = []
        hasAttemptedInitialReviewsLoad = false
    }

    /// Checks if user has reviewed a place (using database-verified IDs).
    func hasVerifiedReviewedPlace(placeId: String) -> Bool {
        return verifiedReviewedPlaceIds.contains(placeId)
    }

    /// Loads verified reviewed place IDs from database for accurate filtering.
    func loadVerifiedReviewedPlaceIds(for placeIds: [String]) async {
        guard let userId = userSession?.currentUserId else { return }
        guard !placeIds.isEmpty else { return }
        guard !isLoadingVerifiedReviewedIds else { return }

        isLoadingVerifiedReviewedIds = true

        do {
            let ids = try await SupabaseReviewService.shared.getReviewedPlaceIds(
                userId: userId,
                placeIds: placeIds
            )
            verifiedReviewedPlaceIds = ids
        } catch {
            print("❌ [ProfileReviewsViewModel] Error loading verified reviewed IDs: \(error)")
        }

        isLoadingVerifiedReviewedIds = false
    }

    /// Resets all reviews data (used during logout).
    func resetAllData() {
        isLoadingReviewedPlaces = false
        isLoadingMoreReviews = false
        hasMoreReviews = true
        lightweightReviewedPlaces.removeAll()
        totalReviewedPlacesCount = 0
        verifiedReviewedPlaceIds.removeAll()
        isLoadingVerifiedReviewedIds = false
        hasAttemptedInitialReviewsLoad = false
    }

    // MARK: - Private Methods

    /// Loads initial reviewed places from database.
    private func loadInitialReviewedPlaces() async {
        guard let userId = userSession?.currentUserId else {
            print("⚠️ [ProfileReviewsViewModel] Cannot load initial reviewed places: no user ID")
            return
        }

        isLoadingReviewedPlaces = true
        hasAttemptedInitialReviewsLoad = true

        defer {
            isLoadingReviewedPlaces = false
        }

        do {
            // Fetch first page and total count in parallel
            async let placesTask = userService.fetchUserReviewedPlaces(userId: userId, limit: reviewsPerPage, offset: 0)
            async let countTask = SupabaseUserService.shared.getNumberReviewedPlaces(forUserId: userId)

            let lightweightPlaces = try await placesTask
            let totalCount = (try? await countTask) ?? 0

            lightweightReviewedPlaces = lightweightPlaces
            totalReviewedPlacesCount = totalCount
            hasMoreReviews = !lightweightPlaces.isEmpty && lightweightPlaces.count >= reviewsPerPage

            // Load full place details for display (non-blocking)
            Task {
                await loadPlaceDetailsForReviews(lightweightPlaces, userId: userId)
            }
        } catch {
            print("❌ [ProfileReviewsViewModel] Error loading initial reviewed places: \(error.localizedDescription)")
            hasMoreReviews = false
        }
    }

    // MARK: - Place Details Loading

    /// Loads full place details for reviewed places.
    private func loadPlaceDetailsForReviews(_ lightweightPlaces: [LightweightPlace], userId: String) async {
        for place in lightweightPlaces {
            let placeId = place.place_id

            // Load place details if not already loaded
            do {
                let detailPlace = try await placeService.fetchPlace(withId: placeId)
                await MainActor.run {
                    onPlacesUpdate?(placeId, detailPlace)
                    onFetchPlaceImage?(placeId)
                }
            } catch {
                print("❌ [ProfileReviewsViewModel] Failed to load place \(placeId): \(error.localizedDescription)")
            }

            // Add current user as saver so reviewed places appear on map with profile picture
            onPlaceSaversUpdate?(placeId, userId, true)
        }

        // Recalculate map annotations to include new reviewed places
        onAnnotationPlacesRecalculate?()

        // Fetch post images for enhanced display
        let placeIds = lightweightPlaces.map { $0.place_id }
        await fetchPostImagesForPlaces(placeIds, userId: userId)
    }

    /// Fetches post images for a batch of places.
    private func fetchPostImagesForPlaces(_ placeIds: [String], userId: String) async {
        // Collect all image URLs first
        var imageUrlsToLoad: [(placeId: String, imageUrl: String)] = []

        // Fetch posts for these places to get images
        for placeId in placeIds {
            do {
                // Get the most recent post for this place by this user
                let (posts, _) = try await postService.fetchPosts(placeId: placeId, latestOnly: false)
                let userPosts = posts.filter { $0.userId == userId }

                if let mostRecentPost = userPosts.first(where: { !$0.images.isEmpty }),
                   let imageUrl = mostRecentPost.images.first,
                   hasPlaceImage?(placeId) != true {
                    imageUrlsToLoad.append((placeId: placeId, imageUrl: imageUrl))
                }
            } catch {
                print("⚠️ [ProfileReviewsViewModel] Failed to fetch post images for place \(placeId): \(error.localizedDescription)")
            }
        }

        // Load all images in parallel
        if !imageUrlsToLoad.isEmpty {
            await withTaskGroup(of: Void.self) { group in
                for (placeId, imageUrl) in imageUrlsToLoad {
                    group.addTask {
                        await self.loadImageFromURL(imageUrl: imageUrl, placeId: placeId)
                    }
                }
            }
        }
    }

    /// Loads an image from URL and stores it as a place image.
    private func loadImageFromURL(imageUrl: String, placeId: String) async {
        guard let url = URL(string: imageUrl) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                await MainActor.run {
                    onPlaceImageUpdate?(placeId, image)
                }
            }
        } catch {
            print("⚠️ [ProfileReviewsViewModel] Failed to load image from URL: \(error.localizedDescription)")
        }
    }
}
