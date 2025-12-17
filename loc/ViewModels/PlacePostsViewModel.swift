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
    @Published var isFavorited: Bool = false
    
    // MARK: - Dependencies
    private let postService: PostService
    private let photosVM: PlacePhotosViewModel
    private let selectedPlaceVM: SelectedPlaceViewModel
    private let notificationManager: NotificationManager
    private let userSession: UserSession
    private let profileVM: ProfileViewModel
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Loading State
    enum LoadingState {
        case idle
        case loading
        case loaded
        case error(Error)
    }
    
    // MARK: - Initialization
    init(postService: PostService,
         photosViewModel: PlacePhotosViewModel,
         selectedPlaceVM: SelectedPlaceViewModel,
         notificationManager: NotificationManager,
         userSession: UserSession,
         profileVM: ProfileViewModel) {
        self.postService = postService
        self.photosVM = photosViewModel
        self.selectedPlaceVM = selectedPlaceVM
        self.notificationManager = notificationManager
        self.userSession = userSession
        self.profileVM = profileVM
        
        setupObservers()
    }
    
    // MARK: - Setup
    private func setupObservers() {
        observePlaceChanges()
        observePostUpdates()
        observeHighlightedPost()
        observeFavoriteStatus()
    }
    
    /// Observes when the selected place changes to load initial posts
    private func observePlaceChanges() {
        selectedPlaceVM.$selectedPlace
            .sink { [weak self] place in
                guard let self = self else { return }
                self.place = place
                self.posts = self.selectedPlaceVM.posts
                
                if let placeId = place?.id.uuidString {
                    self.loadPosts(for: placeId)
                }
            }
            .store(in: &cancellables)
    }
    
    /// Observes when posts are added, modified, or deleted to refresh the feed
    private func observePostUpdates() {
        selectedPlaceVM.$postsUpdateCounter
            .dropFirst() // Skip initial value to avoid redundant updates on setup
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.posts = self.selectedPlaceVM.posts
            }
            .store(in: &cancellables)
    }
    
    /// Observes deep link notifications to highlight specific posts
    private func observeHighlightedPost() {
        notificationManager.$highlightedReviewId
            .sink { [weak self] postId in
                self?.highlightedPostId = postId
            }
            .store(in: &cancellables)
    }
    
    /// Observes favorite status changes for the current place.
    /// Monitors both lightweightFavorites and userFavorites since isPlaceFavorite checks both.
    private func observeFavoriteStatus() {
        Publishers.CombineLatest3(
            selectedPlaceVM.$selectedPlace,
            profileVM.$lightweightFavorites,
            profileVM.$userFavorites
        )
        .receive(on: RunLoop.main) // Ensure UI updates on main thread
        .sink { [weak self] place, _, _ in
            guard let self = self, let place = place else {
                self?.isFavorited = false
                return
            }
            let newFavoriteState = self.profileVM.isPlaceFavorite(placeId: place.id.uuidString)
            if self.isFavorited != newFavoriteState {
                print("⭐ [PlacePostsVM] Favorite status changed: \(self.isFavorited) → \(newFavoriteState)")
                self.isFavorited = newFavoriteState
            }
        }
        .store(in: &cancellables)
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
    func loadPosts(for placeId: String) {
        let vmLoadingState = selectedPlaceVM.postLoadingState(forPlaceId: placeId)
        
        switch vmLoadingState {
        case .idle:
            loadingState = .idle
        case .loading:
            loadingState = .loading
        case .loaded:
            loadingState = .loaded
        case .error(let error):
            loadingState = .error(error)
        }
    }
    
    func checkLikeStatuses() {
        guard let userId = userSession.currentUserId else { return }
        selectedPlaceVM.checkLikeStatuses(userId: userId)
    }
    
    func toggleFavorite() {
        guard let place = place else { return }
        if isFavorited {
            profileVM.removeFavoritePlace(place: place)
        } else {
            profileVM.addFavoritePlace(place: place)
        }
    }
    
    // MARK: - Photo Management
    func getPhotoLoadingState(for post: PlacePost) -> PlacePhotosViewModel.LoadingState {
        photosVM.photoLoadingState(forPostId: post.id)
    }
    
    func getPhotos(for post: PlacePost) -> [UIImage] {
        photosVM.photos(forPostId: post.id)
    }
    
    func loadMorePhotos(for postId: String, allImageUrls: [String]) {
        photosVM.loadMorePostPhotos(for: postId, allImageUrls: allImageUrls)
    }
    
    func reloadPhotos(for post: PlacePost) {
        photosVM.reloadPostPhotos(for: post)
    }
    
    func getPost(by id: String) -> PlacePost? {
        selectedPlaceVM.getPost(by: id)
    }
    
    func clearHighlightedPost() {
        notificationManager.clearHighlightedReview()
    }
}

