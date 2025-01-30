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
    @Published var userResults: [ProfileData] = []
    @Published var selectedUser: ProfileData?
    @Published var isUserDetailPresented = false
    @Published var userLocation: CLLocationCoordinate2D?
    private let googlePlacesService = GooglePlacesService()
    private let firestoreService = FirestoreService()

    weak var selectedPlaceVM: SelectedPlaceViewModel?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Observing searchText changes with debounce to limit API calls
        $searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] text in
                self?.searchPlaces(query: text)
                self?.searchUsers(query: text)
            }
            .store(in: &cancellables)
    }

    private func searchPlaces(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        googlePlacesService.performSearch(query: query, userLocation: userLocation) { [weak self] results, error in
            if let error = error {
                print("Error fetching autocomplete results: \(error.localizedDescription)")
                return
            }
            DispatchQueue.main.async {
                self?.searchResults = results ?? []
            }
        }
    }
    
    private func searchUsers(query: String) {
        guard !query.isEmpty else {
            userResults = []
            return
        }
        
        firestoreService.searchUsers(query: query) { [weak self] users, error in
            if let error = error {
                print("Error searching users: \(error.localizedDescription)")
                return
            }
            DispatchQueue.main.async {
                self?.userResults = users ?? []
            }
        }
    }
    
    func selectPlace(_ prediction: GMSAutocompletePrediction) {
        googlePlacesService.fetchPlace(placeID: prediction.placeID) { [weak self] place, error in
            if let error = error {
                print("Error fetching place: \(error.localizedDescription)")
                return
            }
            
            guard let place = place else {
                print("No place details found.")
                return
            }
            
            DispatchQueue.main.async {
                self?.selectedPlaceVM?.selectedPlace = place
                self?.selectedPlaceVM?.isDetailSheetPresented = true
            }
        }
    }
}
