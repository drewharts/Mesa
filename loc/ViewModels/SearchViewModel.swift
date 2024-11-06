//
//  SearchViewModel.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/5/24.
//


import SwiftUI
import GooglePlaces
import Combine

class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var searchResults: [GMSAutocompletePrediction] = [] // Use GMSAutocompletePrediction directly
    @Published var selectedPlace: GMSPlace? // Use GMSPlace directly
    @Published var userLocation: CLLocationCoordinate2D?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Observing searchText changes with debounce to limit API calls
        $searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] text in
                self?.performSearch(query: text)
            }
            .store(in: &cancellables)
    }

    private func performSearch(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        let placesClient = GMSPlacesClient.shared()
        let filter = GMSAutocompleteFilter()
        filter.types = ["establishment"] // Use a string array directly for types
        
        if let location = userLocation {
            filter.locationBias = GMSPlaceRectangularLocationOption(
                CLLocationCoordinate2D(latitude: location.latitude + 0.01, longitude: location.longitude + 0.01),
                CLLocationCoordinate2D(latitude: location.latitude - 0.01, longitude: location.longitude - 0.01)
            )
        }
        
        placesClient.findAutocompletePredictions(fromQuery: query, filter: filter, sessionToken: nil) { [weak self] results, error in
            if let error = error {
                print("Error fetching autocomplete results: \(error)")
                return
            }
            DispatchQueue.main.async {
                self?.searchResults = results ?? []
            }
        }
    }
    
    func selectPlace(_ prediction: GMSAutocompletePrediction) {
        let placesClient = GMSPlacesClient.shared()
        placesClient.fetchPlace(fromPlaceID: prediction.placeID, placeFields: .all, sessionToken: nil) { [weak self] place, error in
            if let error = error {
                print("Error fetching place details: \(error)")
                return
            }
            DispatchQueue.main.async {
                self?.selectedPlace = place
                self?.searchResults.removeAll() // Clear results after selecting a place
            }
        }
    }
}
