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
    @Published private var placePhotos: [String: [UIImage]] = [:] // Cache for place-level photos by placeId
    @Published private var placeReviews: [String: [Review]] = [:] // Cache for reviews by placeId
    @Published private var reviewPhotos: [String: [UIImage]] = [:] // Cache for review photos by reviewId
    @Published private var userProfilePhotos: [String: UIImage] = [:] // Cache for profile photos by userId
    
    @Published var placeRating: Double = 0
    
    @Published private var photoLoadingStates: [String: LoadingState] = [:] // Loading states for place photos
    @Published private var reviewPhotoLoadingStates: [String: LoadingState] = [:] // Loading states for review photos
    @Published private var profilePhotoLoadingStates: [String: LoadingState] = [:] // Loading states for profile photos
    @Published private var reviewLoadingStates: [String: LoadingState] = [:] // Loading states for reviews

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
                return true // All errors considered equal for simplicity
            default:
                return false
            }
        }
    }
    
    // MARK: - Initialization
    init(locationManager: LocationManager, firestoreService: FirestoreService) {
        self.locationManager = locationManager
        self.firestoreService = firestoreService
    }
    
    // MARK: - Private Methods
    private func loadData(for place: DetailPlace, currentLocation: CLLocationCoordinate2D) {
        print("Loading data for \(place.name) at location \(currentLocation)")
        DispatchQueue.main.async {
            self.isDetailSheetPresented = true
        }
    }
    
    private func loadReviews(for place: DetailPlace) {
        let placeId = place.id.uuidString
        DispatchQueue.main.async {
            self.reviewLoadingStates[placeId] = .loading
        }
        
        firestoreService.fetchReviews(placeId: placeId) { [weak self] reviews, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    print("Error fetching reviews for place \(place.name): \(error.localizedDescription)")
                    self.reviewLoadingStates[placeId] = .error(error)
                    self.placeReviews[placeId] = []
                } else {
                    let fetchedReviews = reviews ?? []
                    self.placeReviews[placeId] = fetchedReviews
                    if self.selectedPlace?.id.uuidString == placeId {
                        self.placeRating = self.calculateAvgRating(for: placeId)
                    }
                    fetchedReviews.forEach { review in
                        self.loadReviewPhotos(for: review)
                        self.loadProfilePhoto(for: review)
                    }
                    self.reviewLoadingStates[placeId] = .loaded
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
    
    private func loadProfilePhoto(for review: Review) {
        let userId = review.userId
        let photoUrlString = review.profilePhotoUrl
        
        guard !photoUrlString.isEmpty else {
            DispatchQueue.main.async {
                self.profilePhotoLoadingStates[userId] = .loaded
                self.userProfilePhotos[userId] = nil
            }
            return
        }
        
        if userProfilePhotos[userId] != nil {
            return
        }
        
        DispatchQueue.main.async {
            self.profilePhotoLoadingStates[userId] = .loading
        }
        
        guard let url = URL(string: photoUrlString) else {
            DispatchQueue.main.async {
                self.profilePhotoLoadingStates[userId] = .error(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid profile photo URL"]))
                self.userProfilePhotos[userId] = nil
            }
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    print("Error fetching profile photo for user \(userId): \(error.localizedDescription)")
                    self.profilePhotoLoadingStates[userId] = .error(error)
                    self.userProfilePhotos[userId] = nil
                } else if let data = data, let image = UIImage(data: data) {
                    self.userProfilePhotos[userId] = image
                    self.profilePhotoLoadingStates[userId] = .loaded
                } else {
                    self.profilePhotoLoadingStates[userId] = .error(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode profile photo"]))
                    self.userProfilePhotos[userId] = nil
                }
            }
        }.resume()
    }
    
    // MARK: - Public Methods
    func addReview(_ review: Review) {
        guard let placeId = selectedPlace?.id.uuidString else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            var currentReviews = self.placeReviews[placeId] ?? []
            currentReviews.append(review)
            self.placeReviews[placeId] = currentReviews
            self.placeRating = self.calculateAvgRating(for: placeId)
            self.loadReviewPhotos(for: review)
            self.loadProfilePhoto(for: review)
        }
    }
    
    func formattedTimestamp(for review: Review) -> String {
        let now = Date()
        let calendar = Calendar.current
        let daysSince = calendar.dateComponents([.day], from: review.timestamp, to: now).day ?? 0
        
        if daysSince < 30 {
            return daysSince == 0 ? "Today" : "\(daysSince) day\(daysSince == 1 ? "" : "s") ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: review.timestamp)
        }
    }
    
    // MARK: - Public Accessors
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
    
    func photos(for review: Review) -> [UIImage] {
        return reviewPhotos[review.id] ?? []
    }
    
    func photoLoadingState(for review: Review) -> LoadingState {
        return reviewPhotoLoadingStates[review.id] ?? .idle
    }
    
    func profilePhoto(forUserId userId: String) -> UIImage? {
        return userProfilePhotos[userId]
    }
    
    func profilePhotoLoadingState(forUserId userId: String) -> LoadingState {
        return profilePhotoLoadingStates[userId] ?? .idle
    }
    
    func reviewLoadingState(forPlaceId placeId: String) -> LoadingState {
        return reviewLoadingStates[placeId] ?? .idle
    }
}
