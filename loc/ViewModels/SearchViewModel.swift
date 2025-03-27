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
                self?.searchUsers(query: text)
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
                    existingDetailPlace.OpenHours = DetailPlace.serializeOpenHours(openHours)
                    
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
            
            // Save the new DetailPlace to Firestore if it doesn't exist
            self?.firestoreService.addToAllPlaces(detailPlace: detailPlace) { error in
                if let error = error {
                    print("Error saving new place to Firestore: \(error.localizedDescription)")
                }
            }
            
            // Return the newly created DetailPlace
            completion(detailPlace)
        }
    }
    
    func selectSuggestion(_ suggestion: SearchSuggestion) {
        print("🔍 User selected suggestion: \(suggestion.id) - \(suggestion.name)")
        mapboxSearchService.selectSuggestion(
            suggestion,
            onResultResolved: { [weak self] result in
                DispatchQueue.main.async {
                    print("✅ Resolved result: \(result.id) - \(result.name)")

                    // Use the asynchronous searchResultToDetailPlace with a completion handler
                    self?.searchResultToDetailPlace(place: result) { [weak self] detailPlace in
                        guard let self = self else { return }
                        self.selectedPlaceVM?.selectedPlace = detailPlace
                        self.selectedPlaceVM?.isDetailSheetPresented = true
                    }
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
