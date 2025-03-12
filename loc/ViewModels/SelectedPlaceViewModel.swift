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
    @Published private var placePhotos: [String: [UIImage]] = [:] // Cache photos by placeId
    @Published private var placeReviews: [String: [Review]] = [:] // Cache reviews by placeId
    @Published var placeRating: Double = 0 // Current rating for selectedPlace
    
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
                self.placeReviews[placeId] = reviews ?? []
                if self.selectedPlace?.id.uuidString == placeId {
                    self.placeRating = self.calculateAvgRating(for: placeId)
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
        firestoreService.fetchPhotosFromStorage(placeId: placeId) { [weak self] images, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error fetching photos for place \(placeId): \(error.localizedDescription)")
                return
            }
            
            DispatchQueue.main.async {
                self.placePhotos[placeId] = images ?? []
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
            
            // Update the rating since we added a new review
            self.placeRating = self.calculateAvgRating(for: placeId)
        }
    }
    
    // Helper to access reviews for the currently selected place
    var reviews: [Review] {
        guard let placeId = selectedPlace?.id.uuidString else { return [] }
        return placeReviews[placeId] ?? []
    }
    
    // Helper to access photos for the currently selected place
    var photos: [UIImage] {
        guard let placeId = selectedPlace?.id.uuidString else { return [] }
        return placePhotos[placeId] ?? []
    }
}
