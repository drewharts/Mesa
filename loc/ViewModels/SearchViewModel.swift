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
import FirebaseFirestore

class SearchViewModel: ObservableObject {
    @Published var searchText = ""  // User's search input
    @Published var searchResults: [MesaPlaceSuggestion] = []
    @Published var userResults: [ProfileData] = []
    @Published var searchError: String?
    @Published var selectedUser: ProfileData?

    weak var selectedPlaceVM: SelectedPlaceViewModel?

    private let firestoreService = FirestoreService()
//    private let mapboxSearchService = MapboxSearchService()
    private let searchService = PlaceSearchService()
    
    private var cancellables = Set<AnyCancellable>()

    init() {
        
        // ✅ Debounce to limit API calls while typing
        $searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main) // 300ms delay
            .removeDuplicates() // Avoid duplicate searches
            .sink { [weak self] text in
                self?.searchPlaces(query: text)
                self?.searchUsers(query: text)
            }
            .store(in: &cancellables)
    }

    func searchPlaces(query: String) {
        searchService.searchPlaces(
            query: query,
            onResultsUpdated: { [weak self] results in
                if let mesaSuggestions = results as? [MesaPlaceSuggestion] {
                    DispatchQueue.main.async {
                        self?.searchResults = mesaSuggestions
                    }
                }
            },
            onError: { [weak self] error in
                DispatchQueue.main.async {
                    self?.searchError = error
                }
            }
        )
    }
    
    private func searchResultToDetailPlace(place: SearchResult, completion: @escaping (DetailPlace) -> Void) {
        // First, check if the DetailPlace exists in Firestore using mapboxId
        firestoreService.findPlace(mapboxId: place.mapboxId!) { [weak self] existingDetailPlace, error in
            if let error = error {
                print("Error checking for existing place: \(error.localizedDescription)")
                // If there's an error, proceed to create a new DetailPlace (or handle differently)
            }
            
            if var existingDetailPlace = existingDetailPlace {
                // Update the OpenHours for the existing place
                if let openHours = place.metadata?.openHours as? OpenHours {
                    existingDetailPlace.openHours = DetailPlace.serializeOpenHours(openHours)
                    
                    // Update the place in Firestore
                    self?.firestoreService.updatePlace(detailPlace: existingDetailPlace) { error in
                        if let error = error {
                            print("Error updating place hours in Firestore: \(error.localizedDescription)")
                        }
                        completion(existingDetailPlace)
                    }
                } else {
                    completion(existingDetailPlace)
                }
                return
            }
            
            // If no existing place is found, create a new DetailPlace using the initializer
            var detailPlace = DetailPlace(from: place)
            
            // Return the newly created DetailPlace
            completion(detailPlace)
        }
    }
    
    func selectSuggestion(_ suggestion: MesaPlaceSuggestion) {
        print("🔍 User selected suggestion: \(suggestion.id) - \(suggestion.name)")
        searchService.selectSuggestion(
            suggestion,
            onResultResolved: { [weak self] result in
                DispatchQueue.main.async {
                    self?.selectedPlaceVM?.selectedPlace = result
                    self?.selectedPlaceVM?.isDetailSheetPresented = true
                    
                    // Print detailed information about the place
                    print("✅ Place Details Result:")
                    print("  ID: \(result.id)")
                    print("  Name: \(result.name)")
                    print("  Address: \(result.address)")
                    print("  Location: (\(result.coordinate?.latitude ?? 0), \(result.coordinate?.longitude ?? 0))")
                    print("  Source: local")
                    print("  Open Hours: \(result.openHours?.joined(separator: ", ") ?? "Not available")")
                    print("  Phone: \(result.phone ?? "Not available")")
                    print("  Description: \(result.description ?? "Not available")")
                    print("  Categories: \(result.categories?.joined(separator: ", ") ?? "None")")
                    print("  Rating: \(result.rating ?? 0)")
                    print("  Price Level: \(result.priceLevel ?? "Not available")")
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
