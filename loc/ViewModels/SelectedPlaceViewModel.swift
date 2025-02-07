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
    @Published var selectedPlace: (any SearchResult)? {
        didSet {
            if let place = selectedPlace,
               let currentLocation = locationManager.currentLocation {
                loadData(for: place, currentLocation: currentLocation.coordinate)
            }
        }
    }
    
    @Published var isDetailSheetPresented: Bool = false
    
    private let locationManager: LocationManager
    
    // ✅ Inject LocationManager via initializer
    init(locationManager: LocationManager) {
        self.locationManager = locationManager
    }
    
    private func loadData(for place: any SearchResult, currentLocation: CLLocationCoordinate2D) {
        print("Loading data for \(place.name) at location \(currentLocation)")
        isDetailSheetPresented = true
    }
}
