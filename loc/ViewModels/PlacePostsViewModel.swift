//
//  PlacePostsViewModel.swift
//  loc
//
//  ViewModel for displaying place posts feed
//

import Foundation
import UIKit
import Combine

@MainActor
class PlacePostsViewModel: ObservableObject {
    // MARK: - Published State
    @Published var posts: [PlacePost] = []
    @Published var loadingState: LoadingState = .idle
    @Published var place: DetailPlace?
    @Published var highlightedPostId: String?

    // MARK: - Dependencies (Services only)
    private let postService: PostService
    private let photosVM: PlacePhotosViewModel
    private let notificationManager: NotificationManager
    private let userSession: UserSession

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Callbacks
    /// Called when like statuses need to be checked
    var onCheckLikeStatuses: ((String) -> Void)?

    // MARK: - Loading State
    enum LoadingState {
        case idle
        case loading
        case loaded
        case error(Error)
    }

    // MARK: - Initialization
    /// Initializes the ViewModel with required services.
    init(photosViewModel: PlacePhotosViewModel,
         notificationManager: NotificationManager,
         userSession: UserSession) {
        self.postService = ServiceContainer.shared.postService
        self.photosVM = photosViewModel
        self.notificationManager = notificationManager
        self.userSession = userSession

        setupObservers()
    }

    // MARK: - Setup
    private func setupObservers() {
        observeHighlightedPost()
    }

    /// Observes deep link notifications to highlight specific posts.
    private func observeHighlightedPost() {
        notificationManager.$highlightedReviewId
            .sink { [weak self] postId in
                self?.highlightedPostId = postId
            }
            .store(in: &cancellables)
    }

    // MARK: - Data-Driven Methods

    /// Sets the current place.
    func setPlace(_ place: DetailPlace?) {
        self.place = place
        if place == nil {
            posts = []
            loadingState = .idle
        }
    }

    /// Sets the posts for the current place.
    func setPosts(_ posts: [PlacePost]) {
        self.posts = posts
    }

    /// Sets the loading state for posts.
    func setLoadingState(_ state: LoadingState) {
        self.loadingState = state
    }

    // MARK: - Computed Properties
    var hasPosts: Bool {
        !posts.isEmpty
    }

    var emptyStateMessage: String {
        "Be the first to share your experience!"
    }

    var photosViewModel: PlacePhotosViewModel {
        photosVM
    }

    // MARK: - Actions

    /// Requests like status check via callback.
    func checkLikeStatuses() {
        guard let userId = userSession.currentUserId else { return }
        onCheckLikeStatuses?(userId)
    }

    // MARK: - Photo Management

    /// Returns the photo loading state for a specific post.
    func getPhotoLoadingState(for post: PlacePost) -> PlacePhotosViewModel.LoadingState {
        photosVM.photoLoadingState(forPostId: post.id)
    }

    /// Returns the loaded photos for a specific post.
    func getPhotos(for post: PlacePost) -> [UIImage] {
        photosVM.photos(forPostId: post.id)
    }

    /// Loads more photos for a specific post.
    func loadMorePhotos(for postId: String, allImageUrls: [String]) {
        photosVM.loadMorePostPhotos(for: postId, allImageUrls: allImageUrls)
    }

    /// Reloads all photos for a specific post.
    func reloadPhotos(for post: PlacePost) {
        photosVM.reloadPostPhotos(for: post)
    }

    /// Returns a post by its ID from the local posts array.
    func getPost(by id: String) -> PlacePost? {
        posts.first { $0.id == id }
    }

    /// Clears the highlighted post notification.
    func clearHighlightedPost() {
        notificationManager.clearHighlightedReview()
    }
}

