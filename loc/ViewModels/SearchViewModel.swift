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
    @Published var userLocation: CLLocationCoordinate2D?
    
    weak var selectedPlaceVM: SelectedPlaceViewModel?

    
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
        filter.types = ["restaurant"] // Use a string array directly for types
        
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

        let myProperties = [GMSPlaceProperty.all].map {$0.rawValue}
        let placeRequest = GMSFetchPlaceRequest(placeID: prediction.placeID, placeProperties: myProperties, sessionToken: nil)
        placesClient.fetchPlace(with: placeRequest, callback: {
            (place: GMSPlace?, error: Error?) in
            guard let place, error == nil else { return }
            DispatchQueue.main.async {
                self.selectedPlaceVM?.selectedPlace = place
                self.selectedPlaceVM?.isDetailSheetPresented = true
            }
        })
    }
}
