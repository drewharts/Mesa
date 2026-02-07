//
//  PlacePhotosViewModel.swift
//  loc
//
//  Coordinator ViewModel for place photos. Owns child ViewModels for external review photos
//  and post/profile photos. Manages place-level gallery photos directly.
//  Data-Driven: Receives place/posts data via setPlace()/setPosts() instead of observing ViewModels.
//

import Foundation
import UIKit
import Combine

@MainActor
class PlacePhotosViewModel: ObservableObject {
    // MARK: - Child ViewModels
    let externalReviewPhotosVM = ExternalReviewPhotosViewModel()
    let postPhotosVM = PostPhotosViewModel()

    // MARK: - Place Gallery State
    @Published private var placePhotoItems: [String: [PhotoItem]] = [:]
    @Published private var photoLoadingStates: [String: LoadingState] = [:]
    @Published private var photoPageLimit = 9
    @Published private var allPhotosLoaded = false
    @Published private var postsLoadingFinished: Bool = false

    @Published var place: DetailPlace?
    @Published var placeId: String = ""

    // MARK: - Deduplication
    private var loadedPlacePhotoURLs: [String: Set<String>] = [:]

    // Store current posts for photo loading
    private var currentPosts: [PlacePost] = []

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Loading State Enum
    enum LoadingState: Equatable {
        case idle
        case loading
        case loaded
        case error(Error)

        static func == (lhs: LoadingState, rhs: LoadingState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.loading, .loading), (.loaded, .loaded):
                return true
            case (.error, .error):
                return true
            default:
                return false
            }
        }
    }

    // MARK: - Initialization
    init() {
        setupChildObservers()
    }

    /// Forwards objectWillChange from child VMs so views observing this coordinator re-render.
    private func setupChildObservers() {
        externalReviewPhotosVM.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        postPhotosVM.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: - Data-Driven Updates

    /// Called by parent when the selected place changes.
    /// Skips loading when the place has a placeholder UUID (not yet resolved from backend).
    func setPlace(_ place: DetailPlace?) {
        self.place = place
        self.placeId = place?.id.uuidString ?? ""

        guard let place = place, !place.hasPlaceholderID else { return }

        print("📸 [PlacePhotosVM] setPlace called for: \(place.id.uuidString)")
        postsLoadingFinished = false
        resetPlaceGallery()
        externalReviewPhotosVM.setPlace(place)
    }

    /// Updates whether posts have finished loading from PlacePostsCacheService.
    func setPostsLoadingFinished(_ finished: Bool) {
        postsLoadingFinished = finished
    }

    /// Called by parent when posts are loaded or updated.
    func setPosts(_ posts: [PlacePost]) {
        self.currentPosts = posts
        guard let place = place else { return }
        loadPhotosForCurrentPosts(place: place, posts: posts)
    }

    /// Loads photos for all current posts.
    private func loadPhotosForCurrentPosts(place: DetailPlace, posts: [PlacePost]) {
        getPlacePhotos(for: place, loadMore: false)

        for post in posts {
            postPhotosVM.loadPostPhotos(for: post)
            postPhotosVM.loadProfilePhotoFromURL(userId: post.userId, photoUrl: post.profilePhotoUrl)
        }
    }

    // MARK: - Public Computed Properties (Facade)

    /// Photo items for place-level gallery.
    var photoItems: [PhotoItem] {
        guard let placeId = place?.id.uuidString else { return [] }
        return placePhotoItems[placeId] ?? []
    }

    /// Loading state for place gallery photos.
    var photoLoadingState: LoadingState {
        guard let placeId = place?.id.uuidString else { return .idle }
        return photoLoadingStates[placeId] ?? .idle
    }

    /// External review photo items (delegated to child VM).
    var externalPhotoItems: [PhotoItem] {
        return externalReviewPhotosVM.externalPhotoItems
    }

    /// Loading state for external review photos (delegated to child VM).
    var externalReviewPhotoLoadingState: LoadingState {
        return mapExternalLoadingState(externalReviewPhotosVM.externalReviewPhotoLoadingState)
    }

    /// Whether all external review photos have been loaded.
    var externalReviewPhotosFullyLoaded: Bool {
        return externalReviewPhotosVM.externalReviewPhotosFullyLoaded
    }

    /// Whether external review images are currently being refreshed after 403 errors.
    var isRefreshingImages: Bool {
        return externalReviewPhotosVM.isRefreshingImages
    }

    /// Combined photo items from both place gallery and external sources.
    var combinedPhotoItems: [PhotoItem] {
        return photoItems + externalPhotoItems
    }

    /// URLs for all combined photos (for photo viewer).
    var combinedPhotoURLs: [String] {
        return combinedPhotoItems.map { $0.url }
    }

    /// Total count of all available photos.
    var totalPhotoCount: Int {
        return photoItems.count + externalPhotoItems.count
    }

    /// Whether any photo loading is in progress (includes waiting for posts to finish loading).
    var isAnyPhotosLoading: Bool {
        let galleryLoading = photoLoadingState == .loading
        let externalLoading = externalReviewPhotoLoadingState == .loading
        return galleryLoading || externalLoading || !postsLoadingFinished
    }

    /// Whether all place gallery photos have been loaded.
    var allPhotosLoadedForCurrentPlace: Bool {
        return allPhotosLoaded
    }

    // MARK: - Public Methods

    /// Loads more place gallery photos.
    func loadMorePhotos() {
        guard let place = place, !allPhotosLoaded else { return }
        getPlacePhotos(for: place, loadMore: true)
    }

    /// Loads initial external review photos if not already loaded (delegated to child VM).
    func loadInitialExternalReviewPhotos() {
        externalReviewPhotosVM.loadInitialExternalReviewPhotos()
    }

    /// Loads more external review photos when nearing the end of the list (delegated to child VM).
    func loadMoreExternalReviewPhotosIfNeeded(currentIndex: Int) {
        externalReviewPhotosVM.loadMoreExternalReviewPhotosIfNeeded(currentIndex: currentIndex)
    }

    /// Reports a failed external image load to trigger batched refresh.
    func reportExternalImageLoadFailure(url: String) {
        externalReviewPhotosVM.reportImageLoadFailure(url: url)
    }

    // MARK: - Post & Profile Photo Accessors (Delegated to PostPhotosVM)

    /// Loads photos for a specific post.
    func loadPostPhotos(for post: PlacePost) {
        postPhotosVM.loadPostPhotos(for: post)
    }

    /// Loads more photos for a specific post when user scrolls.
    func loadMorePostPhotos(for postId: String, allImageUrls: [String]) {
        postPhotosVM.loadMorePostPhotos(for: postId, allImageUrls: allImageUrls)
    }

    /// Reloads photos for a specific post.
    func reloadPostPhotos(for post: PlacePost) {
        postPhotosVM.reloadPostPhotos(for: post)
    }

    /// Loads a profile photo from URL.
    func loadProfilePhotoFromURL(userId: String, photoUrl: String) {
        postPhotosVM.loadProfilePhotoFromURL(userId: userId, photoUrl: photoUrl)
    }

    /// Returns loaded photos for a specific post.
    func photos(forPostId postId: String) -> [UIImage] {
        return postPhotosVM.photos(forPostId: postId)
    }

    /// Returns loading state for a specific post's photos.
    func photoLoadingState(forPostId postId: String) -> LoadingState {
        return mapPostLoadingState(postPhotosVM.photoLoadingState(forPostId: postId))
    }

    /// Returns cached profile photo for a user.
    func profilePhoto(forUserId userId: String) -> UIImage? {
        return postPhotosVM.profilePhoto(forUserId: userId)
    }

    /// Returns loading state for a user's profile photo.
    func profilePhotoLoadingState(forUserId userId: String) -> LoadingState {
        return mapPostLoadingState(postPhotosVM.profilePhotoLoadingState(forUserId: userId))
    }

    // MARK: - Private Methods

    /// Maps ExternalReviewPhotosViewModel.LoadingState to PlacePhotosViewModel.LoadingState.
    private func mapExternalLoadingState(_ state: ExternalReviewPhotosViewModel.LoadingState) -> LoadingState {
        switch state {
        case .idle: return .idle
        case .loading: return .loading
        case .loaded: return .loaded
        case .error(let error): return .error(error)
        }
    }

    /// Maps PostPhotosViewModel.LoadingState to PlacePhotosViewModel.LoadingState.
    private func mapPostLoadingState(_ state: PostPhotosViewModel.LoadingState) -> LoadingState {
        switch state {
        case .idle: return .idle
        case .loading: return .loading
        case .loaded: return .loaded
        case .error(let error): return .error(error)
        }
    }

    /// Resets place gallery photo state when switching to a new place.
    private func resetPlaceGallery() {
        guard let placeId = place?.id.uuidString else { return }

        placePhotoItems[placeId]?.removeAll()
        photoLoadingStates[placeId] = .idle
        allPhotosLoaded = false
        loadedPlacePhotoURLs[placeId]?.removeAll()
    }

    /// Collects photo URLs from posts and creates PhotoItems.
    private func getPlacePhotos(for place: DetailPlace, loadMore: Bool = false) {
        let placeId = place.id.uuidString

        if photoLoadingStates[placeId] == .loading && !loadMore {
            return
        }

        photoLoadingStates[placeId] = .loading

        let urlsToFetch = collectUniquePhotoURLs(for: placeId)

        if urlsToFetch.isEmpty {
            photoLoadingStates[placeId] = .loaded
            if placePhotoItems[placeId] == nil {
                placePhotoItems[placeId] = []
            }
            allPhotosLoaded = true
            return
        }

        let newItems = urlsToFetch.map { PhotoItem(url: $0) }
        let existingItems = placePhotoItems[placeId] ?? []
        placePhotoItems[placeId] = existingItems + newItems

        markURLsAsLoaded(urlsToFetch, for: placeId)
        photoLoadingStates[placeId] = .loaded
    }

    /// Collects unique photo URLs from posts, excluding already-loaded URLs.
    private func collectUniquePhotoURLs(for placeId: String) -> [String] {
        let posts = currentPosts
        let loadedURLs = loadedPlacePhotoURLs[placeId] ?? []

        var seenURLs = Set<String>()
        var uniqueURLs: [String] = []

        for post in posts {
            for url in post.images {
                guard !loadedURLs.contains(url), !seenURLs.contains(url) else { continue }
                seenURLs.insert(url)
                uniqueURLs.append(url)
            }
        }

        let limit = min(photoPageLimit, uniqueURLs.count)
        return Array(uniqueURLs.prefix(limit))
    }

    /// Marks URLs as loaded to prevent future duplicate loads.
    private func markURLsAsLoaded(_ urls: [String], for placeId: String) {
        if loadedPlacePhotoURLs[placeId] == nil {
            loadedPlacePhotoURLs[placeId] = []
        }
        loadedPlacePhotoURLs[placeId]?.formUnion(urls)
    }
}
