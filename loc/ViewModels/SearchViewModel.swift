//
//  SearchViewModel.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/5/24.
//

import SwiftUI
import Combine
import MapboxSearch
import CoreLocation

class SearchViewModel: ObservableObject {
    @Published var searchText = ""  // User's search input
    @Published var searchResults: [SearchSuggestion] = []
    @Published var userResults: [ProfileData] = []
    @Published var searchError: String?
    @Published var selectedUser: ProfileData?

    weak var selectedPlaceVM: SelectedPlaceViewModel?

    private let firestoreService = FirestoreService()
    private let mapboxSearchService = MapboxSearchService()
    
    private var cancellables = Set<AnyCancellable>()

    init() {
        
        // ✅ Debounce to limit API calls while typing
        $searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main) // 300ms delay
            .removeDuplicates() // Avoid duplicate searches
            .sink { [weak self] text in
                self?.searchPlaces(query: text)
            }
            .store(in: &cancellables)
    }

    func searchPlaces(query: String) {
        mapboxSearchService.searchPlaces(
            query: query,
            onResultsUpdated: { [weak self] results in
                DispatchQueue.main.async {
                    self?.searchResults = results
                }
            },
            onError: { [weak self] error in
                DispatchQueue.main.async {
                    self?.searchError = error
                }
            }
        )
    }
    
    func selectSuggestion(_ suggestion: SearchSuggestion) {
        print("🔍 User selected suggestion: \(suggestion.id) - \(suggestion.name)")
        mapboxSearchService.selectSuggestion(
            suggestion,
            onResultResolved: { [weak self] result in
                DispatchQueue.main.async {
                    print("✅ Resolved result: \(result.id) - \(result.name)")

                    self?.selectedPlaceVM?.selectedPlace = result
                    self?.selectedPlaceVM?.isDetailSheetPresented = true
                }
            }
        )
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
}

//class SearchViewModel: ObservableObject, SearchEngineDelegate {
//    
//    @Published var searchText = ""
//    @Published var searchResults: [GMSAutocompletePrediction] = []
//    @Published var userResults: [ProfileData] = []
//    @Published var selectedUser: ProfileData?
//    @Published var isUserDetailPresented = false
//    @Published var userLocation: CLLocationCoordinate2D?
//    private let googlePlacesService = GooglePlacesService()
//    private let mapboxSearchEngine = SearchEngine()
//    private let firestoreService = FirestoreService()
//
//    weak var selectedPlaceVM: SelectedPlaceViewModel?
//    
//    private var cancellables = Set<AnyCancellable>()
//    
//    init() {
//        mapboxSearchEngine.delegate = self
//        // Observing searchText changes with debounce to limit API calls
//        $searchText
//            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
//            .sink { [weak self] text in
//                self?.searchPlaces(query: text)
//                self?.searchUsers(query: text)
//            }
//            .store(in: &cancellables)
//    }
//
//    private func searchPlaces(query: String) {
//        guard !query.isEmpty else {
//            searchResults = []
//            return
//        }
//        
//        mapboxSearchEngine.query = query
//        if let location = userLocation {
//            let options = SearchOptions(proximity: location)
//            mapboxSearchEngine.search(query: query, options: options)
//        } else {
//            mapboxSearchEngine.search(query: query)
//        }
////        googlePlacesService.performSearch(query: query, userLocation: userLocation) { [weak self] results, error in
////            if let error = error {
////                print("Error fetching autocomplete results: \(error.localizedDescription)")
////                return
////            }
////            DispatchQueue.main.async {
////                self?.searchResults = results ?? []
////            }
////        }
//    }
//    
//    private func searchUsers(query: String) {
//        guard !query.isEmpty else {
//            userResults = []
//            return
//        }
//        
//        firestoreService.searchUsers(query: query) { [weak self] users, error in
//            if let error = error {
//                print("Error searching users: \(error.localizedDescription)")
//                return
//            }
//            DispatchQueue.main.async {
//                self?.userResults = users ?? []
//            }
//        }
//    }
//    
//    func selectPlace(_ prediction: GMSAutocompletePrediction) {
//        googlePlacesService.fetchPlace(placeID: prediction.placeID) { [weak self] place, error in
//            if let error = error {
//                print("Error fetching place: \(error.localizedDescription)")
//                return
//            }
//            
//            guard let place = place else {
//                print("No place details found.")
//                return
//            }
//            
//            DispatchQueue.main.async {
//                self?.selectedPlaceVM?.selectedPlace = place
//                self?.selectedPlaceVM?.isDetailSheetPresented = true
//            }
//        }
//    }
//}
