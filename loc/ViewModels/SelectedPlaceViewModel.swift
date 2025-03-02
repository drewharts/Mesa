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
    @Published var selectedPlace: ( DetailPlace)? {
        didSet {
            if let place = selectedPlace,
               let currentLocation = locationManager.currentLocation {
                loadData(for: place, currentLocation: currentLocation.coordinate)
                loadReviews(for: place)
            }
        }
    }
    
    @Published var isDetailSheetPresented: Bool = false
    
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
        
    }
}
