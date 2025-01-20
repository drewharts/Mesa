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
    @Published var searchResults: [GMSAutocompletePrediction] = []
    @Published var selectedPlace: GMSPlace?
    @Published var userLocation: CLLocationCoordinate2D?

    private var cancellables = Set<AnyCancellable>()
    private let placesClient = GMSPlacesClient.shared()

    init() {
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

        let filter = GMSAutocompleteFilter()
        filter.types = ["restaurant"]

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
        let placeProperties = [GMSPlaceProperty.all].map { $0.rawValue }
        let placeRequest = GMSFetchPlaceRequest(placeID: prediction.placeID, placeProperties: placeProperties, sessionToken: nil)

        placesClient.fetchPlace(with: placeRequest) { [weak self] place, error in
            guard let place = place, error == nil else {
                print("Error fetching place details: \(error!)")
                return
            }
            DispatchQueue.main.async {
                // Update selectedPlace and clear searchResults only after place details are fetched
                self?.selectedPlace = place
                self?.searchResults = [] // Clear results after selecting a place
            }
        }
    }
}
