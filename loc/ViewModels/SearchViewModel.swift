//
//  SearchViewModel.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/5/24.
//  Refactored for clean MVVM with single responsibility
//

import SwiftUI
import Combine
import CoreLocation

/// ViewModel for search functionality
/// Single Responsibility: Coordinate search operations and manage search state
@MainActor
class SearchViewModel: ObservableObject {
    // MARK: - Published State
    @Published var searchText = ""
    @Published var searchResults: [MesaPlaceSuggestion] = []
    @Published var userResults: [ProfileData] = []
    @Published var searchError: String?
    @Published var showNoPlaceFound: Bool = false
    @Published var isSearching: Bool = false
    
    /// Snapshot of user profile photos - updates only when search completes
    /// This prevents main thread blocking from reactive observation of ProfilePhotoCache
    @Published private(set) var userPhotosSnapshot: [String: UIImage] = [:]
    
    // MARK: - Dependencies (Services only, NOT other ViewModels)
    private let placeService: PlaceService
    private let userService: UserService
    private let locationManager: LocationManager
    private let searchService = PlaceSearchService()
    private let photoCache = ProfilePhotoCache.shared
    
    // MARK: - Private State
    private var searchCache: [String: [MesaPlaceSuggestion]] = [:]
    private var currentSearchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var hasSetupPipeline = false  // ✅ Track if pipeline is setup
    
    // MARK: - Callbacks (instead of direct ViewModel references)
    var onPlaceSelected: ((DetailPlace) -> Void)?
    
    // MARK: - Initialization
    init(placeService: PlaceService, userService: UserService, locationManager: LocationManager) {
        self.placeService = placeService
        self.userService = userService
        self.locationManager = locationManager
        
        // ✅ Staff Engineer: Defer Combine setup until needed (prevents main thread blocking)
    }
    
    // MARK: - Setup
    
    /// Setup search pipeline lazily (only when actually needed)
    /// Staff Engineer: Defer expensive work to prevent blocking during view creation
    func setupIfNeeded() {
        guard !hasSetupPipeline else { return }
        hasSetupPipeline = true
        setupSearchPipeline()
    }
    
    private func setupSearchPipeline() {
        // Debounced search pipeline
        $searchText
            .debounce(for: .milliseconds(150), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .filter { !$0.isEmpty && $0.count >= 2 }
            .sink { [weak self] text in
                self?.currentSearchTask?.cancel()
                self?.isSearching = true
                
                self?.currentSearchTask = Task {
                    await self?.performSearch(query: text)
                }
            }
            .store(in: &cancellables)
        
        // Clear results immediately when search text is empty
        $searchText
            .filter { $0.isEmpty }
            .sink { [weak self] _ in
                self?.clearResults()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Search Methods
    
    /// Clear all search results
    private func clearResults() {
        currentSearchTask?.cancel()
        currentSearchTask = nil
        searchResults = []
        userResults = []
        userPhotosSnapshot = [:]  // Clear photo snapshot
        searchError = nil
        showNoPlaceFound = false
        isSearching = false
    }
    
    /// Perform search for places and users
    private func performSearch(query: String) async {
        // Check if task was cancelled
        guard !Task.isCancelled else { return }
        
        // Check cache first for instant results
        if let cachedResults = searchCache[query] {
            searchResults = cachedResults
            showNoPlaceFound = cachedResults.isEmpty
            isSearching = false
            return
        }
        
        // Clear previous results
        searchResults = []
        searchError = nil
        showNoPlaceFound = false
        
        // Perform parallel search operations
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.searchPlaces(query: query)
            }
            group.addTask {
                await self.searchUsers(query: query)
            }
        }
    }
    
    /// Search for places
    private func searchPlaces(query: String) async {
        let latitude = locationManager.currentLocation?.coordinate.latitude
        let longitude = locationManager.currentLocation?.coordinate.longitude
        
        await withCheckedContinuation { continuation in
            searchService.searchPlaces(
                query: query,
                latitude: latitude,
                longitude: longitude,
                onResultsUpdated: { [weak self] results in
                    guard let self = self else {
                        continuation.resume()
                        return
                    }
                    
                    self.searchResults = results
                    self.showNoPlaceFound = results.isEmpty
                    self.isSearching = false
                    
                    // Cache the results
                    self.searchCache[query] = results
                    self.limitCacheSize()
                    
                    continuation.resume()
                },
                onError: { [weak self] error in
                    self?.searchError = error
                    self?.showNoPlaceFound = false
                    self?.isSearching = false
                    continuation.resume()
                }
            )
        }
    }
    
    /// Search for users
    private func searchUsers(query: String) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            userService.searchUsers(query: query) { [weak self] users, error in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                if let users = users {
                    let profiles = users.compactMap { user in
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
                    }
                    
                    Task { @MainActor in
                        self.userResults = profiles
                        // Prefetch photos using shared cache
                        await self.prefetchProfilePhotos(for: profiles)
                        // Create snapshot AFTER photos load to prevent reactive updates
                        self.createPhotoSnapshot()
                    }
                } else if let error = error {
                    print("⚠️ [SearchViewModel] User search error: \(error.localizedDescription)")
                }
                
                continuation.resume()
            }
        }
    }
    
    /// Prefetch profile photos for search results
    private func prefetchProfilePhotos(for users: [ProfileData]) async {
        await withTaskGroup(of: Void.self) { group in
            for user in users {
                guard let photoURL = user.profilePhotoURL else { continue }
                group.addTask {
                    await self.photoCache.loadPhoto(userId: user.id, photoURL: photoURL)
                }
            }
        }
    }
    
    /// Create a snapshot of current profile photos
    /// Single Responsibility: Provide view-ready photo data without reactive observation
    private func createPhotoSnapshot() {
        // Create a copy to avoid reactive binding to the cache's @Published property
        userPhotosSnapshot = photoCache.photos
    }
    
    // MARK: - Public Methods
    
    /// Handle selection of a place suggestion
    func selectSuggestion(_ suggestion: MesaPlaceSuggestion) {
        searchService.selectSuggestion(suggestion) { [weak self] result in
            // Use callback instead of direct ViewModel access
            self?.onPlaceSelected?(result)
        }
    }
    
    // MARK: - Cache Management
    
    /// Limit cache size to prevent memory issues
    private func limitCacheSize() {
        if searchCache.count > 50 {
            let keysToRemove = Array(searchCache.keys.prefix(searchCache.count - 50))
            keysToRemove.forEach { searchCache.removeValue(forKey: $0) }
        }
    }
}
