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
import MapKit

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

    /// Keyword-matched results from local database
    @Published var keywordResults: [DetailPlace] = []
    @Published var matchedKeyword: String? = nil
    @Published var hasMoreKeywordResults: Bool = false
    @Published var isLoadingMoreKeywords: Bool = false

    /// AI-powered suggestions child ViewModel
    let aiSuggestionsViewModel = AISuggestionsViewModel()

    /// Snapshot of user profile photos - updates only when search completes
    /// This prevents main thread blocking from reactive observation of ProfilePhotoCache
    @Published private(set) var userPhotosSnapshot: [String: UIImage] = [:]

    /// Current map region for viewport-based keyword searches
    /// Set by parent view to enable location-aware keyword results
    var currentMapRegion: MKCoordinateRegion?

    // MARK: - Dependencies (Services only, NOT other ViewModels)
    private let placeService: PlaceService
    private let userService: UserService
    private let locationManager: LocationManager
    private let searchService = PlaceSearchService()
    private let photoCache = ProfilePhotoCache.shared
    private let recentSearchesService = RecentSearchesService.shared
    
    // MARK: - Computed Properties
    
    /// Recent selections (places & users) - delegated to service (no local state duplication)
    var recentSelections: [RecentSelection] {
        recentSearchesService.getRecentSelections()
    }
    
    // MARK: - Private State
    private var searchCache: [String: [MesaPlaceSuggestion]] = [:]
    private var currentSearchTask: Task<Void, Never>?
    private var currentAISearchTask: Task<Void, Never>?  // Separate task for AI search
    private var cancellables = Set<AnyCancellable>()
    private var hasSetupPipeline = false  // ✅ Track if pipeline is setup

    // Keyword pagination state
    private var keywordSearchOffset: Int = 0
    private(set) var currentKeywordTypes: [String] = []
    private let keywordPageSize: Int = 10
    
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
        // Debounced search pipeline (150ms for fast results)
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

        // Separate AI search pipeline (500ms debounce - more expensive call)
        $searchText
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .filter { [weak self] text in
                guard let self = self else { return false }
                return self.shouldUseAISearch(text)
            }
            .sink { [weak self] text in
                self?.currentAISearchTask?.cancel()

                self?.currentAISearchTask = Task {
                    await self?.searchAISuggestions(query: text)
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
        currentAISearchTask?.cancel()
        currentAISearchTask = nil
        searchResults = []
        userResults = []
        keywordResults = []
        matchedKeyword = nil
        userPhotosSnapshot = [:]  // Clear photo snapshot
        searchError = nil
        showNoPlaceFound = false
        isSearching = false

        // Reset keyword search pagination state
        currentKeywordTypes = []
        keywordSearchOffset = 0
        hasMoreKeywordResults = false

        // Clear AI suggestions
        aiSuggestionsViewModel.clear()
    }
    
    /// Perform search for places and users
    private func performSearch(query: String) async {
        // Check if task was cancelled
        guard !Task.isCancelled else { return }

        // Check cache first for instant place results
        if let cachedResults = searchCache[query] {
            searchResults = cachedResults
            showNoPlaceFound = cachedResults.isEmpty
            // Still run keyword search even with cached results
            // (keyword results depend on viewport and aren't cached)
            await searchByKeyword(query: query)
            isSearching = false
            return
        }

        // Clear previous results
        searchResults = []
        keywordResults = []
        matchedKeyword = nil
        searchError = nil
        showNoPlaceFound = false

        // Perform parallel search operations (AI search has separate 500ms debounce pipeline)
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.searchPlaces(query: query)
            }
            group.addTask {
                await self.searchUsers(query: query)
            }
            group.addTask {
                await self.searchByKeyword(query: query)
            }
        }
    }

    /// Search for AI-powered suggestions
    private func searchAISuggestions(query: String) async {
        let latitude = locationManager.currentLocation?.coordinate.latitude ?? 40.7128
        let longitude = locationManager.currentLocation?.coordinate.longitude ?? -74.0060

        print("🤖 [AI Search] Calling AI suggestions API with query: '\(query)', lat: \(latitude), lng: \(longitude)")
        aiSuggestionsViewModel.search(query: query, latitude: latitude, longitude: longitude)
    }

    /// Search for places matching keyword-to-type mappings within current viewport
    private func searchByKeyword(query: String) async {
        let matches = KeywordMappingService.shared.findMatchingKeywords(in: query)

        guard let firstMatch = matches.first else {
            // No keyword matches found
            return
        }

        // Reset pagination for new search
        keywordSearchOffset = 0
        currentKeywordTypes = firstMatch.types

        // Get viewport bounds for location-aware results
        let bounds = getViewportBounds()

        do {
            // Fetch one extra to check if more results exist
            let places = try await SupabasePlaceService.shared.searchPlacesByTypes(
                types: firstMatch.types,
                bounds: bounds,
                limit: keywordPageSize + 1,
                offset: 0
            )

            matchedKeyword = firstMatch.keyword

            // Check if there are more results
            if places.count > keywordPageSize {
                keywordResults = Array(places.prefix(keywordPageSize))
                hasMoreKeywordResults = true
            } else {
                keywordResults = places
                hasMoreKeywordResults = false
            }

            keywordSearchOffset = keywordResults.count
        } catch {
            // Don't log cancellation errors - expected when user types quickly
            if !Task.isCancelled && (error as NSError).code != NSURLErrorCancelled {
                print("❌ [SearchViewModel] Error searching by keyword: \(error)")
            }
        }
    }

    /// Load more keyword search results (pagination)
    func loadMoreKeywordResults() {
        guard !isLoadingMoreKeywords, hasMoreKeywordResults, !currentKeywordTypes.isEmpty else { return }

        isLoadingMoreKeywords = true

        Task {
            let bounds = getViewportBounds()

            do {
                let places = try await SupabasePlaceService.shared.searchPlacesByTypes(
                    types: currentKeywordTypes,
                    bounds: bounds,
                    limit: keywordPageSize + 1,
                    offset: keywordSearchOffset
                )

                // Check if there are more results
                if places.count > keywordPageSize {
                    keywordResults.append(contentsOf: Array(places.prefix(keywordPageSize)))
                    hasMoreKeywordResults = true
                } else {
                    keywordResults.append(contentsOf: places)
                    hasMoreKeywordResults = false
                }

                keywordSearchOffset = keywordResults.count
            } catch {
                // Don't log cancellation errors
                if !Task.isCancelled && (error as NSError).code != NSURLErrorCancelled {
                    print("❌ [SearchViewModel] Error loading more keyword results: \(error)")
                }
            }

            isLoadingMoreKeywords = false
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
    
    /// Handles selection of a place suggestion with immediate navigation.
    func selectSuggestion(_ suggestion: MesaPlaceSuggestion) {
        recentSearchesService.savePlace(
            id: suggestion.id,
            name: suggestion.name,
            address: suggestion.address
        )

        // Navigate immediately with minimal data - full details fetched in background
        let minimalPlace = DetailPlace(
            googlePlaceId: suggestion.id,
            name: suggestion.name,
            address: suggestion.address,
            coordinate: suggestion.coordinate,
            source: suggestion.source
        )
        onPlaceSelected?(minimalPlace)
    }
    
    /// Save a user selection to recent history
    func saveUserSelection(_ user: ProfileData) {
        recentSearchesService.saveUser(
            id: user.id,
            name: user.fullName,
            profilePhotoURL: user.profilePhotoURL?.absoluteString
        )
    }

    /// Save an AI-suggested place selection to recent history
    func saveAIPlaceSelection(_ place: DetailPlace) {
        recentSearchesService.savePlace(
            id: place.id.uuidString,
            name: place.name,
            address: place.address
        )
    }
    
    /// Handle selection of a recent place (fetch full details and navigate)
    /// Uses PlaceSearchService to resolve external IDs (Google/Mapbox) via Mesa backend
    func selectRecentPlace(id: String) {
        searchService.retrievePlaceById(placeId: id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let place):
                    guard let fullPlace = place as? DetailPlace else {
                        print("⚠️ [SearchViewModel] Failed to cast place result to DetailPlace")
                        return
                    }
                    self?.onPlaceSelected?(fullPlace)
                case .failure(let error):
                    print("⚠️ [SearchViewModel] Failed to fetch recent place: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Clear recent selection history
    func clearRecentSearches() {
        recentSearchesService.clearAll()
        objectWillChange.send()  // Notify views to refresh
    }
    
    // MARK: - AI Search Detection

    /// Determine if a query should trigger AI search
    /// Simple rule: if query is long enough, use AI search
    private func shouldUseAISearch(_ query: String) -> Bool {
        let shouldTrigger = query.count > 15

        if shouldTrigger {
            print("🤖 [AI Search] Triggering for query (\(query.count) chars): '\(query)'")
        }

        return shouldTrigger
    }

    // MARK: - Cache Management

    /// Limit cache size to prevent memory issues
    private func limitCacheSize() {
        if searchCache.count > 50 {
            let keysToRemove = Array(searchCache.keys.prefix(searchCache.count - 50))
            keysToRemove.forEach { searchCache.removeValue(forKey: $0) }
        }
    }

    // MARK: - Viewport Helpers

    /// Convert current map region to adaptive viewport bounds for database queries
    /// Uses ViewportBoundsHelper to ensure bounds are within reasonable min/max thresholds
    /// Falls back to user's current location if no map region is available
    private func getViewportBounds() -> (northLat: Double, southLat: Double, eastLng: Double, westLng: Double)? {
        return ViewportBoundsHelper.getAdaptiveBounds(
            from: currentMapRegion,
            fallbackLocation: locationManager.currentLocation?.coordinate
        )
    }
}
