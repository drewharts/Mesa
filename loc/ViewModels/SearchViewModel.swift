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
    @Published var showNoPlaceFound: Bool = false  // Track when search returns no results

    weak var selectedPlaceVM: SelectedPlaceViewModel?
    weak var placeTypeFilterVM: PlaceTypeFilterViewModel?

    private let placeService: PlaceService
    private let userService: UserService
    private let locationManager: LocationManager
//    private let mapboxSearchService = MapboxSearchService()
    private let searchService = PlaceSearchService()

    private var cancellables = Set<AnyCancellable>()

    init(placeService: PlaceService, userService: UserService, locationManager: LocationManager) {
        // Initialize dependencies through dependency injection
        self.placeService = placeService
        self.userService = userService
        self.locationManager = locationManager
        
        // ✅ Debounce to limit API calls while typing
        $searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main) // 300ms delay
            .removeDuplicates() // Avoid duplicate searches
            .sink { [weak self] text in
                print("🔍 [SearchViewModel] Search text changed: '\(text)'")
                self?.searchPlaces(query: text)
                self?.searchUsers(query: text)
                // Update place type filters based on search text
                Task { @MainActor in
                    self?.placeTypeFilterVM?.filterBySearchText(text)
                }
            }
            .store(in: &cancellables)
    }

    func searchPlaces(query: String) {
        print("🔍 [SearchViewModel] searchPlaces called with query: '\(query)'")
        
        // Clear previous results first
        searchResults = []
        searchError = nil
        showNoPlaceFound = false
        
        guard !query.isEmpty else {
            print("🔍 [SearchViewModel] Query is empty, clearing results")
            return
        }
        
        // Get current location for location-aware search
        let latitude = locationManager.currentLocation?.coordinate.latitude
        let longitude = locationManager.currentLocation?.coordinate.longitude

        print("🔍 [SearchViewModel] Calling searchService.searchPlaces...")
        print("🔍 [SearchViewModel] Using location: lat=\(latitude ?? 0), lng=\(longitude ?? 0)")
        searchService.searchPlaces(
            query: query,
            latitude: latitude,
            longitude: longitude,
            onResultsUpdated: { [weak self] results in
                print("🔍 [SearchViewModel] Received \(results.count) place results")
                for (index, result) in results.enumerated() {
                    print("🔍 [SearchViewModel] Result \(index + 1): \(result.name) - \(result.address ?? "No address")")
                }
                DispatchQueue.main.async {
                    self?.searchResults = results
                    // Show "no place found" message if search was performed but no results found
                    self?.showNoPlaceFound = results.isEmpty && !query.isEmpty
                    print("🔍 [SearchViewModel] Updated searchResults with \(results.count) items")
                    print("🔍 [SearchViewModel] showNoPlaceFound: \(self?.showNoPlaceFound ?? false)")
                }
            },
            onError: { [weak self] error in
                print("❌ [SearchViewModel] Search error: \(error)")
                DispatchQueue.main.async {
                    self?.searchError = error
                    self?.showNoPlaceFound = false  // Don't show "no place found" on error
                    print("❌ [SearchViewModel] Updated searchError: \(error)")
                }
            }
        )
    }
    
    private func searchResultToDetailPlace(place: SearchResult, completion: @escaping (DetailPlace) -> Void) {
        // First, check if the DetailPlace exists in Firestore using mapboxId
        placeService.findPlace(mapboxId: place.mapboxId!) { [weak self] existingDetailPlace, error in
            if let error = error {
                print("Error checking for existing place: \(error.localizedDescription)")
                // If there's an error, proceed to create a new DetailPlace (or handle differently)
            }
            
            if var existingDetailPlace = existingDetailPlace {
                // Update the OpenHours for the existing place
                if let openHours = place.metadata?.openHours as? OpenHours {
                    existingDetailPlace.openHours = DetailPlace.serializeOpenHours(openHours)
                    
                    // Update the place in Firestore
                    self?.placeService.updatePlace(detailPlace: existingDetailPlace) { error in
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
            let detailPlace = DetailPlace(from: place)
            
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
                    print("  Address: \(result.address ?? "Not available")")
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
        print("👥 [SearchViewModel] searchUsers called with query: '\(query)'")
        
        guard !query.isEmpty else {
            print("👥 [SearchViewModel] Query is empty, clearing user results")
            userResults = []
            return
        }

        print("👥 [SearchViewModel] Calling userService.searchUsers...")
        userService.searchUsers(query: query) { [weak self] users, error in
            if let error = error {
                print("❌ [SearchViewModel] User search error: \(error.localizedDescription)")
                return
            }
            print("👥 [SearchViewModel] Received \(users?.count ?? 0) user results")
            DispatchQueue.main.async {
                self?.userResults = users ?? []
                print("👥 [SearchViewModel] Updated userResults with \(users?.count ?? 0) items")
            }
        }
    }
}
