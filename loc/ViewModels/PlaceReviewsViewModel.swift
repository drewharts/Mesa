//
//  PlaceReviewsViewModel.swift
//  loc
//
//  Created by Cursor on 1/22/25.
//  Manages place reviews display with proper MVVM separation
//

import Foundation
import UIKit
import Combine

@MainActor
class PlaceReviewsViewModel: ObservableObject {
    // MARK: - Published State
    @Published var reviews: [any ReviewProtocol] = []
    @Published var loadingState: LoadingState = .idle
    @Published var place: DetailPlace?
    @Published var highlightedReviewId: String?
    
    // MARK: - Dependencies
    private let reviewService: ReviewService
    private let selectedPlaceVM: SelectedPlaceViewModel  // Temporary until fully refactored
    private let notificationManager: NotificationManager
    private let userSession: UserSession
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Loading State
    enum LoadingState {
        case idle
        case loading
        case loaded
        case error(Error)
    }
    
    // MARK: - Initialization
    init(reviewService: ReviewService,
         selectedPlaceVM: SelectedPlaceViewModel,
         notificationManager: NotificationManager,
         userSession: UserSession) {
        self.reviewService = reviewService
        self.selectedPlaceVM = selectedPlaceVM
        self.notificationManager = notificationManager
        self.userSession = userSession
        
        setupObservers()
    }
    
    // MARK: - Setup
    private func setupObservers() {
        // Observe place changes and update reviews
        selectedPlaceVM.$selectedPlace
            .sink { [weak self] place in
                guard let self = self else { return }
                self.place = place
                // Update reviews from computed property
                self.reviews = self.selectedPlaceVM.reviews
                
                if let placeId = place?.id.uuidString {
                    self.loadReviews(for: placeId)
                }
            }
            .store(in: &cancellables)
        
        // Observe notification highlights
        notificationManager.$highlightedReviewId
            .sink { [weak self] reviewId in
                self?.highlightedReviewId = reviewId
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Computed Properties
    var hasReviews: Bool {
        !reviews.isEmpty
    }
    
    var emptyStateMessage: String {
        "Be the first to write a review!"
    }
    
    // MARK: - Actions
    func loadReviews(for placeId: String) {
        // Reviews are already loaded via selectedPlaceVM observers
        // This maintains current functionality during migration
        let vmLoadingState = selectedPlaceVM.reviewLoadingState(forPlaceId: placeId)
        
        // Convert SelectedPlaceVM.LoadingState to PlaceReviewsViewModel.LoadingState
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
    
    func getPhotoLoadingState<T: ReviewProtocol>(for review: T) -> SelectedPlaceViewModel.LoadingState {
        selectedPlaceVM.photoLoadingState(for: review)
    }
    
    func getPhotos<T: ReviewProtocol>(for review: T) -> [UIImage] {
        selectedPlaceVM.photos(for: review)
    }
    
    func loadMorePhotos(for reviewId: String, allImageUrls: [String]) {
        selectedPlaceVM.loadMoreReviewPhotos(for: reviewId, allImageUrls: allImageUrls)
    }
    
    func reloadPhotos<T: ReviewProtocol>(for review: T) {
        selectedPlaceVM.reloadReviewPhotos(for: review)
    }
    
    func getReview(by id: String) -> (any ReviewProtocol)? {
        selectedPlaceVM.getReview(by: id)
    }
    
    func clearHighlightedReview() {
        notificationManager.clearHighlightedReview()
    }
}

