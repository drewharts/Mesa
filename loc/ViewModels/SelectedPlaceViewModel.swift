//
//  SelectedPlaceViewModel.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/22/25.
//

import Foundation
import GooglePlaces
import MapboxSearch
import CoreLocation

class SelectedPlaceViewModel: ObservableObject {
    private let firestoreService: FirestoreService
    private let locationManager: LocationManager
    
    @Published var selectedPlace: DetailPlace? {
        didSet {
            if let place = selectedPlace,
               let currentLocation = locationManager.currentLocation {
                loadData(for: place, currentLocation: currentLocation.coordinate)
                loadReviews(for: place)
                getPlacePhotos(for: place)
            }
        }
    }
    
    @Published var isDetailSheetPresented: Bool = false
    @Published private var placePhotos: [String: [UIImage]] = [:] // Cache place-level photos
    @Published private var placeReviews: [String: [Review]] = [:] // Cache reviews by placeId
    @Published private var reviewPhotos: [String: [UIImage]] = [:] // Cache photos by reviewId
    @Published var placeRating: Double = 0
    @Published private var photoLoadingStates: [String: LoadingState] = [:] // For place photos
    @Published private var reviewPhotoLoadingStates: [String: LoadingState] = [:] // For review photos

    enum LoadingState {
        case idle
        case loading
        case loaded
        case error(Error)
    }
    
    init(locationManager: LocationManager, firestoreService: FirestoreService) {
        self.locationManager = locationManager
        self.firestoreService = firestoreService
    }
    
    private func loadData(for place: DetailPlace, currentLocation: CLLocationCoordinate2D) {
        print("Loading data for \(place.name) at location \(currentLocation)")
        isDetailSheetPresented = true
    }
    
    private func loadReviews(for place: DetailPlace) {
        let placeId = place.id.uuidString
        firestoreService.fetchReviews(placeId: placeId) { [weak self] reviews, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error fetching reviews for place \(place.name): \(error.localizedDescription)")
                return
            }
            
            DispatchQueue.main.async {
                let fetchedReviews = reviews ?? []
                self.placeReviews[placeId] = fetchedReviews
                if self.selectedPlace?.id.uuidString == placeId {
                    self.placeRating = self.calculateAvgRating(for: placeId)
                }
                // Load photos for each review
                fetchedReviews.forEach { review in
                    self.loadReviewPhotos(for: review)
                }
            }
        }
    }
    
    private func calculateAvgRating(for placeId: String) -> Double {
        guard let reviews = placeReviews[placeId], !reviews.isEmpty else { return 0 }
        let total = reviews.reduce(0.0) { $0 + $1.foodRating }
        return total / Double(reviews.count)
    }
    
    private func getPlacePhotos(for place: DetailPlace) {
        let placeId = place.id.uuidString
        DispatchQueue.main.async {
            self.photoLoadingStates[placeId] = .loading
        }
        
        firestoreService.fetchPhotosFromStorage(placeId: placeId) { [weak self] images, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    print("Error fetching photos for place \(placeId): \(error.localizedDescription)")
                    self.photoLoadingStates[placeId] = .error(error)
                    self.placePhotos[placeId] = []
                } else {
                    self.placePhotos[placeId] = images ?? []
                    self.photoLoadingStates[placeId] = .loaded
                }
            }
        }
    }
    
    private func loadReviewPhotos(for review: Review) {
        let reviewId = review.id
        guard !review.images.isEmpty else {
            DispatchQueue.main.async {
                self.reviewPhotos[reviewId] = []
                self.reviewPhotoLoadingStates[reviewId] = .loaded
            }
            return
        }
        
        DispatchQueue.main.async {
            self.reviewPhotoLoadingStates[reviewId] = .loading
        }
        
        firestoreService.fetchPhotosFromStorage(urls: review.images) { [weak self] images, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    print("Error fetching photos for review \(reviewId): \(error.localizedDescription)")
                    self.reviewPhotoLoadingStates[reviewId] = .error(error)
                    self.reviewPhotos[reviewId] = []
                } else {
                    self.reviewPhotos[reviewId] = images ?? []
                    self.reviewPhotoLoadingStates[reviewId] = .loaded
                }
            }
        }
    }
    
    func addReview(_ review: Review) {
        guard let placeId = selectedPlace?.id.uuidString else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            var currentReviews = self.placeReviews[placeId] ?? []
            currentReviews.append(review)
            self.placeReviews[placeId] = currentReviews
            self.placeRating = self.calculateAvgRating(for: placeId)
            self.loadReviewPhotos(for: review) // Load photos for the new review
        }
    }
    
    var reviews: [Review] {
        guard let placeId = selectedPlace?.id.uuidString else { return [] }
        return placeReviews[placeId] ?? []
    }
    
    var photoLoadingState: LoadingState {
        guard let placeId = selectedPlace?.id.uuidString else { return .idle }
        return photoLoadingStates[placeId] ?? .idle
    }
    
    var photos: [UIImage] {
        guard let placeId = selectedPlace?.id.uuidString else { return [] }
        return placePhotos[placeId] ?? []
    }
    
    // Helper to access photos for a specific review
    func photos(for review: Review) -> [UIImage] {
        return reviewPhotos[review.id] ?? []
    }
    
    func photoLoadingState(for review: Review) -> LoadingState {
        return reviewPhotoLoadingStates[review.id] ?? .idle
    }
}
