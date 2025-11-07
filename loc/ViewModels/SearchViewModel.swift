//
//  SearchViewModel.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/5/24.
//

import SwiftUI
import Combine
import CoreLocation

class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var searchResults: [MesaPlaceSuggestion] = []
    @Published var userResults: [ProfileData] = []
    @Published var searchError: String?
    @Published var selectedUser: ProfileData?
    @Published var showNoPlaceFound: Bool = false  // Track when search returns no results
    @Published var isSearching: Bool = false  // Track when search is in progress

    weak var selectedPlaceVM: SelectedPlaceViewModel?

    private let placeService: PlaceService
    private let userService: UserService
    private let locationManager: LocationManager
//    private let mapboxSearchService = MapboxSearchService()
    private let searchService = PlaceSearchService()
    private let objectId = UUID()  // For debugging instance tracking
    
    // Simple cache for instant repeat searches
    private var searchCache: [String: [MesaPlaceSuggestion]] = [:]
    
    // Track current search task to allow cancellation
    private var currentSearchTask: Task<Void, Never>?

    var debugObjectId: String {
        objectId.uuidString.prefix(8).description
    }

    private var cancellables = Set<AnyCancellable>()

    init(placeService: PlaceService, userService: UserService, locationManager: LocationManager) {
        // Initialize dependencies through dependency injection
        self.placeService = placeService
        self.userService = userService
        self.locationManager = locationManager
        
        // ✅ Optimized pipeline for responsive text input
        $searchText
            .debounce(for: .milliseconds(150), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .filter { !$0.isEmpty && $0.count >= 2 }
            .sink { [weak self] text in
                // Cancel any ongoing search
                self?.currentSearchTask?.cancel()
                
                // Show loading state immediately on main thread
                self?.isSearching = true
                
                // Move heavy operations to background thread
                self?.currentSearchTask = Task {
                    await self?.performSearch(query: text)
                }
            }
            .store(in: &cancellables) // 🔧 FIX: This was missing!

        // Handle empty search text separately to clear results immediately
        $searchText
            .filter { $0.isEmpty }
            .sink { [weak self] _ in
                // Cancel any ongoing search
                self?.currentSearchTask?.cancel()
                self?.currentSearchTask = nil
                
                self?.searchResults = []
                self?.userResults = []
                self?.searchError = nil
                self?.showNoPlaceFound = false
                self?.isSearching = false
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Optimized Search Methods
    
    @MainActor
    private func performSearch(query: String) async {
        // Check if task was cancelled
        if Task.isCancelled { return }
        
        // Check cache first for instant results
        if let cachedResults = searchCache[query] {
            searchResults = cachedResults
            showNoPlaceFound = cachedResults.isEmpty && !query.isEmpty
            isSearching = false
            return
        }
        
        // Check again before clearing results
        if Task.isCancelled { return }
        
        // Clear previous results
        searchResults = []
        searchError = nil
        showNoPlaceFound = false
        
        // Perform search operations
        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                await self?.searchPlacesAsync(query: query)
            }
            group.addTask { [weak self] in
                await self?.searchUsersAsync(query: query)
            }
        }
    }
    
    private func searchPlacesAsync(query: String) async {
        // Get current location for location-aware search
        let latitude = locationManager.currentLocation?.coordinate.latitude
        let longitude = locationManager.currentLocation?.coordinate.longitude
        
        await withCheckedContinuation { continuation in
            searchService.searchPlaces(
                query: query,
                latitude: latitude,
                longitude: longitude,
                onResultsUpdated: { [weak self] results in
                    Task { @MainActor in
                        self?.searchResults = results
                        self?.showNoPlaceFound = results.isEmpty && !query.isEmpty
                        self?.isSearching = false
                        
                        // Cache the results
                        self?.searchCache[query] = results
                        if let cache = self?.searchCache, cache.count > 50 {
                            let keysToRemove = Array(cache.keys.prefix(cache.count - 50))
                            keysToRemove.forEach { self?.searchCache.removeValue(forKey: $0) }
                        }
                    }
                    continuation.resume()
                },
                onError: { [weak self] error in
                    Task { @MainActor in
                        self?.searchError = error
                        self?.showNoPlaceFound = false
                        self?.isSearching = false
                    }
                    continuation.resume()
                }
            )
        }
    }
    
    private func searchUsersAsync(query: String) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            userService.searchUsers(query: query) { [weak self] users, error in
                Task { @MainActor in
                    if let error = error {
                        // User search error - silently handle
                    } else {
                        let profileData = users?.compactMap { user in
                            ProfileData(
                                id: user.id,
                                firstName: user.firstName,
                                lastName: user.lastName,
                                email: user.email,
                                profilePhotoURL: user.profilePhotoURL,
                                phoneNumber: "",
                                fullNameLower: user.fullName.lowercased(),
                                fullName: user.fullName,
                                fcmToken: nil,
                                firebaseUid: nil,
                                supabaseUid: nil
                            )
                        } ?? []
                        self?.userResults = profileData
                    }
                }
                continuation.resume()
            }
        }
    }
    
    // Legacy searchPlaces function - kept for compatibility but not used
    func searchPlaces(query: String) {
        // This function is deprecated - use performSearch instead
        Task {
            await performSearch(query: query)
        }
    }
    
    // Removed MapboxSearch searchResultToDetailPlace method - now using Google Places API
    
    func selectSuggestion(_ suggestion: MesaPlaceSuggestion) {
        searchService.selectSuggestion(
            suggestion,
            onResultResolved: { [weak self] result in
                DispatchQueue.main.async {
                    // Animate map to searched place location and fetch fresh details
                    self?.selectedPlaceVM?.selectPlaceAndFetchDetails(result, shouldAnimateMap: true)
                    self?.selectedPlaceVM?.isDetailSheetPresented = true
                }
            }
        )
    }
    
    // Legacy searchUsers function - kept for compatibility but not used
    private func searchUsers(query: String) {
        // This function is deprecated - use searchUsersAsync instead
        Task {
            await searchUsersAsync(query: query)
        }
    }
}
