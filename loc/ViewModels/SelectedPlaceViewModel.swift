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
    var reviews: [Review] = []
    @Published var selectedPlace: DetailPlace? {
        didSet {
            if let place = selectedPlace,
               let currentLocation = locationManager.currentLocation {
                loadData(for: place, currentLocation: currentLocation.coordinate)
                loadReviews(for: place)
                getPlacePhotos(for: place) // Fetch photos when a place is selected
            }
        }
    }
    
    @Published var isDetailSheetPresented: Bool = false
    @Published private var placePhotos: [String: [UIImage]] = [:] // Store photos by placeId
    
    private let locationManager: LocationManager
    
    // ✅ Inject LocationManager via initializer
    init(locationManager: LocationManager, firestoreService: FirestoreService) {
        self.locationManager = locationManager
        self.firestoreService = firestoreService
    }
    
    private func loadData(for place: DetailPlace, currentLocation: CLLocationCoordinate2D) {
        print("Loading data for \(place.name) at location \(currentLocation)")
        isDetailSheetPresented = true
    }
    
    //get reviews here
    private func loadReviews(for place: DetailPlace) {
        firestoreService.fetchReviews(placeId: place.id.uuidString) { [weak self] reviews, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error fetching reviews for place \(place.name): \(error.localizedDescription)")
                return
            }
            
            // Update the reviews on the main thread
            DispatchQueue.main.async {
                self.reviews = reviews ?? []
            }
        }
    }
    
    private func getPlacePhotos(for place: DetailPlace) {
        firestoreService.fetchPhotosFromStorage(placeId: place.id.uuidString) { [weak self] images, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error fetching photos for place \(place.id.uuidString): \(error.localizedDescription)")
                return
            }
            
            if let images = images {
                print("Fetched \(images.count) photos for place \(place.name)")
                // Store the photos in the placePhotos dictionary using the placeId as the key
                DispatchQueue.main.async {
                    self.placePhotos[place.id.uuidString] = images
                }
            } else {
                print("No photos found for place \(place.name)")
                // Optionally, clear the photos for this placeId if none are found
                DispatchQueue.main.async {
                    self.placePhotos[place.id.uuidString] = []
                }
            }
        }
    }

    // Helper method to access photos for a specific place
    func photos(for place: DetailPlace) -> [UIImage] {
        return placePhotos[place.id.uuidString] ?? []
    }
}
