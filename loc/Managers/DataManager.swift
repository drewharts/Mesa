//
//  DataManager.swift
//  loc
//
//  Created by Andrew Hartsfield II on 4/29/25.
//

import Foundation
import UIKit
import CoreLocation
import MapKit

@MainActor
class DataManager: ObservableObject {
    // Firestore Services
    private let userService: UserService
    private let placeService: PlaceService
    private let reviewService: ReviewService
    
    private let userSession: UserSession
    private let locationManager: LocationManager
    private let profileViewModel: ProfileViewModel
    private let detailPlaceViewModel: DetailPlaceViewModel
    
    init(
        userService: UserService,
        placeService: PlaceService,
        reviewService: ReviewService,
        userSession: UserSession,
        locationManager: LocationManager,
        profileViewModel: ProfileViewModel,
        detailPlaceViewModel: DetailPlaceViewModel
    ) {
        self.userService = userService
        self.placeService = placeService
        self.reviewService = reviewService
        self.userSession = userSession
        self.locationManager = locationManager
        self.profileViewModel = profileViewModel
        self.detailPlaceViewModel = detailPlaceViewModel
    }
    
    /// Get current user location for proximity-based sorting
    var currentUserLocation: CLLocationCoordinate2D? {
        return locationManager.currentLocation?.coordinate
    }

    func initializeProfileData(userId: String) async {
        startDataLoadingFlags()
        
        // ✅ PHASE 1: Load ONLY essential data for immediate UI display
        await measureLoadingTime("Essential Data") {
            await loadEssentialDataOnly(userId: userId)
        }
        
        // ✅ PHASE 2: Load viewport places in background (non-blocking)
        Task.detached(priority: .background) { [weak self] in
            await self?.measureLoadingTime("Viewport Places") {
                await self?.loadViewportPlacesOnly(userId: userId)
            }
        }
    }
    
    /// Helper to measure loading time for performance monitoring
    private func measureLoadingTime<T>(_ operation: String, block: () async throws -> T) async rethrows -> T {
        return try await block()
    }
    
    /// Load essential user profile data and all place annotations at startup
    /// Uses the optimized PostgreSQL function to get user + friends' places in one call
    private func loadEssentialDataOnly(userId: String) async {
        // Load only the user's profile data
        await loadProfileData(userId: userId)
                
        // Reset loading flags since we're not loading follower/following profiles yet
        await MainActor.run {
            profileViewModel.isFollowersListLoading = false
            profileViewModel.isFollowingListLoading = false
        }
        
    }
    
    
    /// Load place IDs only (not full place documents) - MUCH faster!
    private func loadUserPlaceIdsOnly(userId: String) async {
        // Load just the IDs/metadata, not full place documents
        async let favoriteIds = try? await placeService.fetchFavoritePlaceIds(userId: userId)
        async let myPlaceIds = try? await placeService.fetchMyPlaceIds(userId: userId)
        async let listMetadata = try? await placeService.fetchListMetadata(userId: userId)
        
        let (favIds, myPlaceIdsResult, listMetadataResult) = await (favoriteIds, myPlaceIds, listMetadata)
        
        await MainActor.run {
            // Store just the IDs - full place data loads on-demand
            self.profileViewModel.userFavorites = favIds ?? []
            self.profileViewModel.myPlaces = myPlaceIdsResult ?? []
            self.profileViewModel.userLists = listMetadataResult ?? []
            
        }
    }
    
    /// ✅ NEW: Load only places in the current viewport (much faster!)
    private func loadViewportPlacesOnly(userId: String) async {
        let startTime = Date()
        
        // Get the current map region from LocationManager
        guard let userLocation = locationManager.currentLocation?.coordinate else {
            print("⚠️ [DataManager] No location available, skipping viewport loading")
            return
        }
        
        // Create a reasonable viewport around user's location
        let viewportRegion = MKCoordinateRegion(
            center: userLocation,
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1) // ~11km radius
        )
        
        do {
            // Use the existing viewport loading logic
            let bounds = getViewportBounds(from: viewportRegion)
            
            // Load places in viewport (much faster than all places!)
            let viewportPlaces = try await placeService.fetchPlacesInViewportWithUserId(
                northLat: bounds.northLat,
                southLat: bounds.southLat,
                eastLng: bounds.eastLng,
                westLng: bounds.westLng,
                userId: userId
            )
            
            // Trigger map annotation calculation for viewport places
            calculateMapAnnotations()
            
        } catch {
            print("❌ [DataManager] Error loading viewport places: \(error.localizedDescription)")
        }
    }
    
    /// Helper to convert region to bounds (same as MapViewModel)
    private func getViewportBounds(from region: MKCoordinateRegion) -> (
        northLat: Double,
        southLat: Double,
        eastLng: Double,
        westLng: Double
    ) {
        let centerLat = region.center.latitude
        let centerLng = region.center.longitude
        let latDelta = region.span.latitudeDelta
        let lngDelta = region.span.longitudeDelta
        
        return (
            northLat: centerLat + (latDelta / 2),
            southLat: centerLat - (latDelta / 2),
            eastLng: centerLng + (lngDelta / 2),
            westLng: centerLng - (lngDelta / 2)
        )
    }
    
    /// PHASE 0: Load ALL user places in a single optimized query
    /// This is the fastest way to get all places on the map
    private func loadAllUserPlacesOptimized(userId: String) async {
        let startTime = Date()
        do {
            let allPlaces = try await placeService.fetchAllUserPlaces(userId: userId)
            
            await MainActor.run {
                // Cache all places in DetailPlaceViewModel
                for place in allPlaces {
                    let placeId = place.id.uuidString
                    self.detailPlaceViewModel.places[placeId] = place
                    self.detailPlaceViewModel.generateColorForPlace(placeId)
                    
                    // Mark user as saver for map display
                    if self.detailPlaceViewModel.placeSavers[placeId] == nil {
                        self.detailPlaceViewModel.placeSavers[placeId] = [userId]
                    } else if !self.detailPlaceViewModel.placeSavers[placeId]!.contains(userId) {
                        self.detailPlaceViewModel.placeSavers[placeId]!.append(userId)
                    }
                }
                
                let duration = Date().timeIntervalSince(startTime)
                print("⚡ [DataManager] Loaded \(allPlaces.count) total places in \(String(format: "%.2f", duration))s")
                
                // Debug: Verify places were stored
                print("🔍 [DataManager] Verification:")
                print("   - Places in detailPlaceVM.places: \(self.detailPlaceViewModel.places.count)")
                print("   - Places in placeSavers: \(self.detailPlaceViewModel.placeSavers.count)")
                print("   - SavedDetailPlaces count: \(self.detailPlaceViewModel.savedDetailPlaces.count)")
                if !allPlaces.isEmpty {
                    let firstPlace = allPlaces[0]
                    print("   - First place: \(firstPlace.name) at \(firstPlace.coordinate?.latitude ?? 0), \(firstPlace.coordinate?.longitude ?? 0)")
                    print("   - Place ID: \(firstPlace.id.uuidString)")
                    print("   - In places dict: \(self.detailPlaceViewModel.places[firstPlace.id.uuidString] != nil)")
                    print("   - In placeSavers: \(self.detailPlaceViewModel.placeSavers[firstPlace.id.uuidString] != nil)")
                }
            }
            
            // Trigger map annotation calculation
            calculateMapAnnotations()
            
        } catch {
            print("❌ [DataManager] Error loading all user places: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Data Loading Methods

    // Sets all relevant loading flags to true before data loading begins
    func startDataLoadingFlags() {
        profileViewModel.isFollowersListLoading = true
        profileViewModel.isFollowingListLoading = true
        profileViewModel.isMyPlacesLoading = true
    }
    
    func calculateMapAnnotations() {
        // ✅ Move to background thread to avoid blocking UI
        Task.detached(priority: .background) {
            await MainActor.run {
                self.detailPlaceViewModel.calculateAnnotationPlaces()
            }
        }
    }
    
    func loadUserMyPlaces(userId: String, offset: Int = 0) async {
        if offset == 0 {
            profileViewModel.isMyPlacesLoading = true
        } else {
            await MainActor.run {
                profileViewModel.isLoadingMoreMyPlaces = true
            }
        }
        
        do {
            // Load 8 places at a time
            let lightweightPlaces = try await userService.fetchUserCreatedPlaces(userId: userId, limit: 8, offset: offset)
            
            // Store lightweight places in ProfileViewModel
            await MainActor.run {
                if offset == 0 {
                    // Initial load - replace existing
                    self.profileViewModel.lightweightMyPlaces = lightweightPlaces
                    self.profileViewModel.myPlaces = lightweightPlaces.map { $0.place_id }
                } else {
                    // Pagination - append new places
                    self.profileViewModel.lightweightMyPlaces.append(contentsOf: lightweightPlaces)
                    self.profileViewModel.myPlaces.append(contentsOf: lightweightPlaces.map { $0.place_id })
                }
                
                // Update hasMore flag
                self.profileViewModel.hasMoreMyPlaces = lightweightPlaces.count >= 8
            }
            
            // Add the current user as a saver for their own places (for map display)
            for place in lightweightPlaces {
                let placeId = place.place_id
                if self.detailPlaceViewModel.placeSavers[placeId] == nil {
                    self.detailPlaceViewModel.placeSavers[placeId] = [userId]
                } else if !self.detailPlaceViewModel.placeSavers[placeId]!.contains(userId) {
                    self.detailPlaceViewModel.placeSavers[placeId]!.append(userId)
                }
            }
            
        } catch {
            print("❌ [DataManager] Error loading my places: \(error.localizedDescription)")
        }
        
        if offset == 0 {
            profileViewModel.isMyPlacesLoading = false
        } else {
            await MainActor.run {
                profileViewModel.isLoadingMoreMyPlaces = false
            }
        }
    }
    
    /// Load more my places (pagination)
    @MainActor
    func loadMoreMyPlaces(userId: String) async {
        guard !profileViewModel.isLoadingMoreMyPlaces && profileViewModel.hasMoreMyPlaces else { return }
        
        let offset = profileViewModel.lightweightMyPlaces.count
        await loadUserMyPlaces(userId: userId, offset: offset)
    }
    
    /// Load user external places (TikTok places) - lightweight with pagination
    /// ⚠️ DEPRECATED: Use ProfileViewModel.loadInitialExternalPlaces() and loadMoreExternalPlaces() instead
    /// This method is kept for backward compatibility but should not be used in new code.
    /// MVVM architecture: ViewModel should own pagination state and logic.
    func loadUserExternalPlaces(userId: String, offset: Int = 0) async {
        if offset == 0 {
            profileViewModel.isLoadingTikTokPlaces = true
        } else {
            await MainActor.run {
                profileViewModel.isLoadingMoreExternalPlaces = true
            }
        }
        
        defer {
            if offset == 0 {
                profileViewModel.isLoadingTikTokPlaces = false
            } else {
                Task { @MainActor in
                    profileViewModel.isLoadingMoreExternalPlaces = false
                }
            }
        }
        
        do {
            // Load 8 places at a time
            let lightweightPlaces = try await userService.fetchUserExternalPlaces(userId: userId, limit: 8, offset: offset)
            
            // Prefetch TikTok metadata for all TikTok URLs to populate cache
            let tiktokUrls = lightweightPlaces.compactMap { $0.tiktok_url }.filter { !$0.isEmpty }
            if !tiktokUrls.isEmpty {
                Task {
                    await TikTokMetadataCache.shared.prefetchMetadata(for: tiktokUrls)
                    print("✅ [DataManager] Prefetched TikTok metadata for \(tiktokUrls.count) URLs")
                }
            }
            
            // Store lightweight places in ProfileViewModel
            await MainActor.run {
                if offset == 0 {
                    // Initial load - replace existing
                    self.profileViewModel.lightweightExternalPlaces = lightweightPlaces
                } else {
                    // Pagination - append new places
                    self.profileViewModel.lightweightExternalPlaces.append(contentsOf: lightweightPlaces)
                }
                
                // Update hasMore flag: false if empty or if we got less than a full page
                self.profileViewModel.hasMoreExternalPlaces = !lightweightPlaces.isEmpty && lightweightPlaces.count >= 8
            }
            
            print("✅ [DataManager] Loaded \(lightweightPlaces.count) lightweight external places (offset: \(offset), hasMore: \(profileViewModel.hasMoreExternalPlaces))")
        } catch {
            print("❌ [DataManager] Error loading external places: \(error.localizedDescription)")
            // Set hasMore to false on error to prevent infinite retry loops
            await MainActor.run {
                profileViewModel.hasMoreExternalPlaces = false
            }
        }
    }
    
    /// Load more external places (pagination)
    /// ⚠️ DEPRECATED: Use ProfileViewModel.loadMoreExternalPlaces() instead
    /// This method is kept for backward compatibility but should not be used in new code.
    /// MVVM architecture: ViewModel should own pagination state and logic.
    @MainActor
    func loadMoreExternalPlaces(userId: String) async {
        guard !profileViewModel.isLoadingMoreExternalPlaces && profileViewModel.hasMoreExternalPlaces else { return }
        
        let offset = profileViewModel.lightweightExternalPlaces.count
        await loadUserExternalPlaces(userId: userId, offset: offset)
    }
    
    /// Refresh My Places data (for when user clicks on My Places)
    func refreshMyPlaces(userId: String) async {
        // Clear existing data and reload
        profileViewModel.myPlaces.removeAll()
        await loadUserMyPlaces(userId: userId)
    }
    
    /// Refresh Reviewed Places data (for when user clicks on My Places)
    func refreshReviewedPlaces(userId: String) async {
        // Clear existing data and reload (server-side pagination)
        profileViewModel.lightweightReviewedPlaces.removeAll()
        profileViewModel.hasMoreReviews = true
        // Reload will happen automatically when view appears
    }
    
    // Load's current user's profile data and profile picture
    func loadProfileData(userId: String) async {
        do {
            let profileData = try await userService.fetchUserById(userId: userId)
            self.profileViewModel.user = profileData
            if let profilePhotoUrl = profileData.profilePhotoURL {
                self.AddProfilePicture(userId: userId, profilePhotoUrl: profilePhotoUrl, isCurrentUser: true)
            }
        } catch {
            print("Error loading profile data: \(error.localizedDescription)")
        }
    }
    
    func downloadImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                print("Error downloading image: \(error?.localizedDescription ?? "Unknown error")")
                completion(nil)
                return
            }
            
            DispatchQueue.main.async {
                completion(UIImage(data: data))
            }
        }.resume()
    }

    func AddProfilePicture(userId: String, profilePhotoUrl: URL, isCurrentUser: Bool = false) {
        // ✅ Move to background thread to avoid blocking UI
        Task.detached(priority: .background) {
            do {
                let (data, _) = try await URLSession.shared.data(from: profilePhotoUrl)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        if isCurrentUser {
                            self.profileViewModel.userPicture = image
                        }
                        self.detailPlaceViewModel.userProfilePicture[userId] = image
                        // ✅ DON'T call calculateAnnotationPlaces here - batch it instead
                        // self.detailPlaceViewModel.calculateAnnotationPlaces()
                    }
                } else {
                    print("Failed to create UIImage from data for profile picture: \(profilePhotoUrl)")
                }
            } catch {
                print("Failed to download profile picture from URL: \(profilePhotoUrl) - \(error.localizedDescription)")
            }
        }
    }
    
    func loadUserFavoritePlaces(userId: String, forUser: ProfileData? = nil) async {
        do {
            let places = try await placeService.fetchProfileFavorites(userId: userId)
            // If this is for the current user, update the ProfileViewModel
            if forUser == nil {
                self.profileViewModel.userFavorites = places.map { $0.id.uuidString }
            }
            // Store DetailPlace objects in DetailPlaceViewModel
            for place in places {
                let placeId = place.id.uuidString
                self.detailPlaceViewModel.places[placeId] = place
                // Update place savers 
                if self.detailPlaceViewModel.placeSavers[placeId] == nil {
                    self.detailPlaceViewModel.placeSavers[placeId] = [userId]
                } else if !self.detailPlaceViewModel.placeSavers[placeId]!.contains(userId) {
                    self.detailPlaceViewModel.placeSavers[placeId]!.append(userId)
                }
            }
        } catch {
            print("Error loading favorite places: \(error.localizedDescription)")
        }
    }
    
    func loadUserPlaceLists(userId: String, forUser: ProfileData? = nil) async {
        do {
            // Use proximity-based sorting if location is available
            let userLocation = locationManager.currentLocation?.coordinate
            let lists: [PlaceList]
            
            if let userLocation = userLocation {
                print("📍 [DataManager] Loading place lists with proximity sorting")
                lists = try await placeService.fetchListsByProximity(userId: userId, userLocation: userLocation)
            } else {
                print("📍 [DataManager] Loading place lists with regular sorting (no location)")
                lists = try await placeService.fetchLists(userId: userId)
            }
            
            // If this is for the current user, update the ProfileViewModel
            if forUser == nil {
                self.profileViewModel.userLists = lists
                // Initialize with empty place arrays - will be populated via place_list_items query
                self.profileViewModel.userListsPlaces = lists.reduce(into: [String: [String]]()) { result, list in
                    result[list.id.uuidString] = []
                }
                
                // If we used proximity sorting, lists are already sorted by distance
                // If we used regular sorting, sort by distance after loading
                if userLocation == nil {
                    self.profileViewModel.sortListsByDistance()
                }
                
                // Use the optimized loading method instead of the old preloading
                print("📍 [DataManager] Triggering optimized list loading...")
                self.profileViewModel.ensureListsLoaded()
            }
        } catch {
            print("Error loading user place lists: \(error.localizedDescription)")
        }
    }
    
    /// Preload place details for the top N lists (sorted by distance)
    /// This improves initial loading experience for the most relevant lists
    private func preloadPlacesForTopLists(lists: [PlaceList], userId: String, topN: Int) async {
        // Sort lists by distance (if they have averageCoordinate) or use first N
        let sortedLists = lists.prefix(topN)
        
        print("📍 [DataManager] Preloading places for \(sortedLists.count) lists...")
        
        // Load places for each of the top lists in parallel
        await withTaskGroup(of: Void.self) { group in
            for list in sortedLists {
                group.addTask {
                    await self.loadPlacesForList(listId: list.id, userId: userId)
                }
            }
        }
        
        // Mark these lists as loaded in ProfileViewModel
        await MainActor.run {
            for list in sortedLists {
                self.profileViewModel.loadedListIds.insert(list.id)
            }
        }
    }
    
    // Optimized to process multiple places concurrently but with limits
    private func processPlacesInListsOptimized(lists: [PlaceList], userId: String) async {
        // Process all places across all lists, but limit concurrency
        var allPlaceIds: [(placeId: String, listId: String)] = []
        for list in lists {
            for place in list.places {
                allPlaceIds.append((place.id.uuidString, list.id.uuidString))
            }
        }
        
        // Process in batches to avoid overwhelming the system
        let batchSize = 10
        for batch in allPlaceIds.chunked(into: batchSize) {
            await withTaskGroup(of: Void.self) { group in
                for (placeId, listId) in batch {
                    group.addTask {
                        await self.fetchAndStorePlaceDetails(placeId: placeId, userId: userId, listId: listId)
                    }
                }
            }
        }
    }
    
    private func fetchAndStorePlaceDetails(placeId: String, userId: String, listId: String) async {
        do {
            let detailPlace = try await placeService.fetchPlace(withId: placeId)
            
            await MainActor.run {
                self.detailPlaceViewModel.places[placeId] = detailPlace
                // Generate color for the place
                self.detailPlaceViewModel.generateColorForPlace(placeId)
                // Update place savers
                if self.detailPlaceViewModel.placeSavers[placeId] == nil {
                    self.detailPlaceViewModel.placeSavers[placeId] = [userId]
                } else if !self.detailPlaceViewModel.placeSavers[placeId]!.contains(userId) {
                    self.detailPlaceViewModel.placeSavers[placeId]!.append(userId)
                }
            }
        } catch {
            print("Error fetching place from Firestore: \(error.localizedDescription)")
            
            // Create fallback DetailPlace from the list data
            if let list = profileViewModel.userLists.first(where: { $0.id.uuidString == listId }),
               let place = list.places.first(where: { $0.id.uuidString == placeId }) {
                let fallbackDetailPlace = DetailPlace(id: place.id, name: place.name, address: place.address, city: nil)
                await MainActor.run {
                    self.detailPlaceViewModel.places[placeId] = fallbackDetailPlace
                    self.detailPlaceViewModel.generateColorForPlace(placeId)
                    // Update place savers
                    if self.detailPlaceViewModel.placeSavers[placeId] == nil {
                        self.detailPlaceViewModel.placeSavers[placeId] = [userId]
                    } else if !self.detailPlaceViewModel.placeSavers[placeId]!.contains(userId) {
                        self.detailPlaceViewModel.placeSavers[placeId]!.append(userId)
                    }
                }
            }
        }
    }
    
    // Load places for a specific list when it becomes visible
    func loadPlacesForList(listId: UUID, userId: String) async {
        guard let list = profileViewModel.userLists.first(where: { $0.id == listId }) else {
            print("❌ [DataManager] loadPlacesForList: List not found for ID \(listId)")
            return
        }
        
        
        // Process places in batches for better performance
        let batchSize = 10
        var loadedPlaceIds: [String] = []
        
        for batch in list.places.chunked(into: batchSize) {
            let batchPlaceIds = batch.map { $0.id.uuidString }
            loadedPlaceIds.append(contentsOf: batchPlaceIds)
            
            // Update UI with current batch
            await MainActor.run {
                self.profileViewModel.userListsPlaces[listId.uuidString] = loadedPlaceIds
            }
            
            // Process places in this batch
            await withTaskGroup(of: Void.self) { group in
                for place in batch {
                    group.addTask {
                        await self.fetchAndStorePlaceDetails(
                            placeId: place.id.uuidString, 
                            userId: userId, 
                            listId: listId.uuidString
                        )
                    }
                }
            }
            
            // Small delay to prevent overwhelming the UI
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
    }

    func processPlacesInList(list: PlaceList, userId: String) async {
        for place in list.places {
            let placeId = place.id.uuidString
            
            if self.detailPlaceViewModel.places[placeId] != nil {
                updateCachedPlace(placeId: placeId, userId: userId)
                continue
            }
            
            await fetchAndUpdatePlace(place: place, userId: userId)
        }
    }
    
    private func updateCachedPlace(placeId: String, userId: String) {
        detailPlaceViewModel.generateColorForPlace(placeId)
        updatePlaceSavers(placeId: placeId, userId: userId)
    }
    
    private func updatePlaceSavers(placeId: String, userId: String) {
        if detailPlaceViewModel.placeSavers[placeId] == nil {
            detailPlaceViewModel.placeSavers[placeId] = [userId]
        } else if !detailPlaceViewModel.placeSavers[placeId]!.contains(userId) {
            detailPlaceViewModel.placeSavers[placeId]!.append(userId)
        }
    }
    
    private func fetchAndUpdatePlace(place: Place, userId: String) async {
        let placeId = place.id.uuidString
        
        do {
            let detailPlace = try await placeService.fetchPlace(withId: placeId)
            detailPlaceViewModel.places[placeId] = detailPlace
            detailPlaceViewModel.generateColorForPlace(placeId)
            updatePlaceSavers(placeId: placeId, userId: userId)
        } catch {
            // Create minimal DetailPlace for missing places
            let detailPlace = DetailPlace(id: place.id, name: place.name, address: place.address, city: nil)
            detailPlaceViewModel.places[placeId] = detailPlace
        }
    }
    
    /// Load following profiles (paginated - 10 at a time)
    /// Pass offset = 0 for initial load, or current count for loading more
    func loadFollowing(userId: String, offset: Int = 0) async {
        let isInitialLoad = offset == 0
        let pageSize = 10
        
        if isInitialLoad {
            await MainActor.run {
                self.profileViewModel.hasMoreFollowing = true
            }
        }
        
        profileViewModel.isFollowingListLoading = true
        
        do {
            let profiles = try await userService.fetchFollowingProfilesData(for: userId, limit: pageSize, offset: offset)
            
            await MainActor.run {
                if isInitialLoad {
                    self.profileViewModel.userFollowing = profiles
                } else {
                    self.profileViewModel.userFollowing.append(contentsOf: profiles)
                }
                
                // If we received fewer profiles than requested, we've reached the end
                if profiles.count < pageSize {
                    self.profileViewModel.hasMoreFollowing = false
                }
            }
            
            // Load profile pictures
            for profile in profiles {
                if let profilePhotoURL = profile.profilePhotoURL {
                    self.AddProfilePicture(userId: profile.id, profilePhotoUrl: profilePhotoURL)
                }
            }
            
            profileViewModel.isFollowingListLoading = false
        } catch {
            print("❌ [DataManager] Error loading following profiles: \(error.localizedDescription)")
            profileViewModel.isFollowingListLoading = false
        }
    }
    
    // Optimized loading for following users' place data
    private func loadFollowingPlacesDataOptimized(profiles: [ProfileData]) async {
        // Process in smaller batches to avoid overwhelming the system
        let batchSize = 5
        for batch in profiles.chunked(into: batchSize) {
            await withTaskGroup(of: Void.self) { group in
                for profile in batch {
                    group.addTask {
                        async let favorites: () = self.loadUserFavoritePlaces(userId: profile.id, forUser: profile)
                        async let lists: () = self.loadUserPlaceLists(userId: profile.id, forUser: profile)
                        await favorites
                        await lists
                    }
                }
            }
        }
    }

    
    /// Load follower profiles (paginated - 10 at a time)
    /// Pass offset = 0 for initial load, or current count for loading more
    func loadFollowers(userId: String, offset: Int = 0) async {
        let isInitialLoad = offset == 0
        let pageSize = 10
        
        if isInitialLoad {
            await MainActor.run {
                self.profileViewModel.hasMoreFollowers = true
            }
        }
        
        profileViewModel.isFollowersListLoading = true
        
        do {
            let profiles = try await userService.fetchFollowerProfilesData(for: userId, limit: pageSize, offset: offset)
            
            await MainActor.run {
                if isInitialLoad {
                    self.profileViewModel.userFollowers = profiles
                } else {
                    self.profileViewModel.userFollowers.append(contentsOf: profiles)
                }
                
                // If we received fewer profiles than requested, we've reached the end
                if profiles.count < pageSize {
                    self.profileViewModel.hasMoreFollowers = false
                }
            }
            
            // Load profile pictures
            for profile in profiles {
                if let profilePhotoURL = profile.profilePhotoURL {
                    self.AddProfilePicture(userId: profile.id, profilePhotoUrl: profilePhotoURL)
                }
            }
            
            profileViewModel.isFollowersListLoading = false
        } catch {
            print("❌ [DataManager] Error loading follower profiles: \(error.localizedDescription)")
            profileViewModel.isFollowersListLoading = false
        }
    }
    
    /// FAST: Load all profile counts, favorites, and place lists in parallel (~20-50ms total!)
    /// Called when profile view appears
    func loadProfileCounts(userId: String) async {
        
        profileViewModel.isFollowersLoading = true
        profileViewModel.isFollowingLoading = true
        profileViewModel.isMyPlacesLoading = true
        
        // Get user location for proximity-based list sorting
        let userLocation = locationManager.currentLocation?.coordinate
        
        // Run all queries in parallel
        async let followers: Int = (try? await userService.getNumberFollowers(forUserId: userId)) ?? 0
        async let following: Int = (try? await userService.getNumberFollowing(forUserId: userId)) ?? 0
        async let myPlaces: Int = (try? await userService.getNumberMyPlaces(forUserId: userId)) ?? 0
        async let totalLists: Int = (try? await userService.getTotalListCount(forUserId: userId)) ?? 0
        async let favorites: [FavoritePlace] = (try? await userService.fetchUserFavorites(userId: userId)) ?? []
        async let totalUniquePlaces: Int = (try? await userService.getTotalPlacesCount(forUserId: userId)) ?? 0
        
        let (followersCount, followingCount, myPlacesCount, totalListCount, favoritePlaces, totalUniquePlacesCount) = await (followers, following, myPlaces, totalLists, favorites, totalUniquePlaces)
        
        // Update counts and favorites immediately - don't wait for place lists
        await MainActor.run {
            profileViewModel.followersCount = followersCount
            profileViewModel.followingCount = followingCount
            profileViewModel.totalListCount = totalListCount
            profileViewModel.totalUniquePlacesCount = totalUniquePlacesCount
            print("🔢 [DataManager] Set totalUniquePlacesCount = \(totalUniquePlacesCount)")
            // Update my places count - we'll store this as the count of myPlaces array
            profileViewModel.myPlaces = Array(repeating: "", count: myPlacesCount) // Placeholder IDs
            profileViewModel.lightweightFavorites = favoritePlaces
            profileViewModel.isFollowersLoading = false
            profileViewModel.isFollowingLoading = false
            profileViewModel.isMyPlacesLoading = false
            
            // Update placeSavers for favorites so "Saved By" feature works
            for favorite in favoritePlaces {
                let placeId = favorite.place_id
                if self.detailPlaceViewModel.placeSavers[placeId] == nil {
                    self.detailPlaceViewModel.placeSavers[placeId] = [userId]
                } else if !self.detailPlaceViewModel.placeSavers[placeId]!.contains(userId) {
                    self.detailPlaceViewModel.placeSavers[placeId]!.append(userId)
                }
            }
            print("📍 [DataManager] Updated placeSavers with \(favoritePlaces.count) favorites")
        }
        
        // Load place lists in background - don't block UI
        if let location = userLocation {
            // Set loading state BEFORE spawning background task (SRP: DataManager coordinates state)
            await MainActor.run {
                self.profileViewModel.isLoadingInitialLists = true
            }
            
            Task.detached(priority: .userInitiated) { [weak self] in
                guard let self = self else { return }
                
                // Guaranteed cleanup of loading state (staff engineer pattern)
                defer {
                    Task { @MainActor in
                        self.profileViewModel.isLoadingInitialLists = false
                    }
                }
                
                let pageSize = 6 // Consistent page size for initial load and pagination
                
                // Fetch owned lists, shared lists, AND collaborative owned lists in parallel
                // This ensures ALL collaborative lists are available for the Shared filter
                async let ownedListsTask = self.userService.fetchPlaceListsByProximity(
                    userId: userId,
                    userLatitude: location.latitude,
                    userLongitude: location.longitude,
                    page: 1,
                    pageSize: pageSize
                )
                async let sharedListsTask = CollaborationService.shared.fetchSharedLists(userId: userId)
                async let collaborativeOwnedTask = CollaborationService.shared.fetchCollaborativeOwnedLists(userId: userId)
                
                let ownedLists = (try? await ownedListsTask) ?? []
                let sharedLists = (try? await sharedListsTask) ?? []
                let collaborativeOwnedLists = (try? await collaborativeOwnedTask) ?? []
                
                // Convert collaborative lists to LightweightPlaceList format
                let sharedAsLightweight = sharedLists.map { $0.toLightweightPlaceList() }
                let collaborativeOwnedAsLightweight = collaborativeOwnedLists.map { $0.toLightweightPlaceList() }
                
                // Get IDs of lists already in owned lists (to avoid duplicates)
                let ownedListIds = Set(ownedLists.map { $0.list_id })
                
                // Filter out collaborative owned lists that are already in paginated owned lists
                let additionalCollaborativeLists = collaborativeOwnedAsLightweight.filter { 
                    !ownedListIds.contains($0.list_id) 
                }
                
                // Merge: owned (paginated) + collaborative owned (not in page 1) + shared with me
                let allLists = ownedLists + additionalCollaborativeLists + sharedAsLightweight
                
                print("📋 [DataManager] Loaded \(ownedLists.count) owned lists + \(additionalCollaborativeLists.count) additional collaborative owned + \(sharedLists.count) shared lists")
                
                // Update place lists on main thread
                await MainActor.run {
                    self.profileViewModel.lightweightPlaceLists = allLists
                    self.profileViewModel.placeListsCurrentPage = 1
                    // Set hasMore based on whether we got a full page of owned lists
                    self.profileViewModel.hasMorePlaceLists = ownedLists.count >= pageSize
                }
                
                // Load places for each list
                if !allLists.isEmpty {
                    await self.loadPlacesForLists(allLists)
                }
            }
        } else {
            print("⚠️ [DataManager] No user location available for place list sorting")
        }
    }
    
    /// Load more place lists (pagination)
    @MainActor
    func loadMorePlaceLists(userId: String, userLatitude: Double? = nil, userLongitude: Double? = nil) async {
        // Guard: Require a valid user ID before attempting pagination
        guard !userId.isEmpty else {
            print("⚠️ [DataManager] Missing user id, deferring loadMorePlaceLists")
            return
        }

        // Guard: Already loading
        guard !profileViewModel.isLoadingMorePlaceLists else {
            print("⚠️ [DataManager] Already loading more place lists, skipping duplicate request")
            return
        }
        
        // Guard: No more lists to load
        guard profileViewModel.hasMorePlaceLists else {
            print("ℹ️ [DataManager] No more place lists to load")
            return
        }
        
        // Use provided coordinates or fall back to user's current location
        let latitude: Double
        let longitude: Double
        
        if let lat = userLatitude, let lng = userLongitude {
            latitude = lat
            longitude = lng
        } else if let location = locationManager.currentLocation?.coordinate {
            latitude = location.latitude
            longitude = location.longitude
        } else {
            print("⚠️ [DataManager] No location available for loading more place lists")
            return
        }
        
        // Set loading state with guaranteed cleanup
        profileViewModel.isLoadingMorePlaceLists = true
        defer { 
            profileViewModel.isLoadingMorePlaceLists = false
        }
        
        let nextPage = profileViewModel.placeListsCurrentPage + 1
        let pageSize = 6
        
        do {
            let moreLists = try await userService.fetchPlaceListsByProximity(
                userId: userId,
                userLatitude: latitude,
                userLongitude: longitude,
                page: nextPage,
                pageSize: pageSize
            )
            
            await MainActor.run {
                // Update pagination state
                // If we got fewer than pageSize items, we've reached the end
                profileViewModel.hasMorePlaceLists = moreLists.count >= pageSize
                
                // Append new lists if any
                if !moreLists.isEmpty {
                    profileViewModel.lightweightPlaceLists.append(contentsOf: moreLists)
                    profileViewModel.placeListsCurrentPage = nextPage
                    
                    for list in moreLists {
                        if profileViewModel.lightweightPlaceListCounts[list.list_id] == nil {
                            profileViewModel.lightweightPlaceListCounts[list.list_id] = list.place_count
                        }
                    }
                } else {
                    profileViewModel.hasMorePlaceLists = false
                }
            }
            
            if !moreLists.isEmpty {
                // Load places for new lists in background
                Task.detached(priority: .userInitiated) { [weak self] in
                    await self?.loadPlacesForLists(moreLists)
                }
            }
        } catch {
            print("❌ [DataManager] Error loading more place lists: \(error.localizedDescription)")
            // Don't set hasMorePlaceLists to false on error - allow retry
        }
    }
    
    /// Load place lists by proximity to a specific place's coordinates (for save-to-list sheet)
    func loadPlaceListsByPlaceCoordinates(userId: String, placeLatitude: Double, placeLongitude: Double) async {
        do {
            let lists = try await userService.fetchPlaceListsByProximity(
                userId: userId,
                userLatitude: placeLatitude,
                userLongitude: placeLongitude,
                page: 1,
                pageSize: 6
            )
            
            await MainActor.run {
                profileViewModel.lightweightPlaceLists = lists
                profileViewModel.placeListsCurrentPage = 1
                profileViewModel.hasMorePlaceLists = lists.count >= 6  // Keep loading if we got 6 or more lists
                
                var updatedCounts: [String: Int] = [:]
                for list in lists {
                    updatedCounts[list.list_id] = profileViewModel.lightweightPlaceListCounts[list.list_id] ?? list.place_count
                }
                profileViewModel.lightweightPlaceListCounts = updatedCounts
            }
            
            // Load places for each list in background
            Task.detached(priority: .userInitiated) { [weak self] in
                await self?.loadPlacesForLists(lists)
            }
        } catch {
            print("❌ [DataManager] Error loading place lists by coordinates: \(error.localizedDescription)")
        }
    }
    
    
    /// Check if a specific place is in a list (for black dot functionality)
    private func checkPlaceInList(listId: String, placeId: String) async -> Bool {
        do {
            // Use a simple query to check if the place exists in the list
            let exists = try await userService.checkPlaceInList(listId: listId, placeId: placeId)
            return exists
        } catch {
            print("❌ [DataManager] Error checking if place \(placeId) is in list \(listId): \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Place List Management
    
    /// Add a place to a list
    func addPlaceToList(listId: String, placeId: String) async throws {
        try await userService.addPlaceToList(listId: listId, placeId: placeId)
    }
    
    /// Remove a place from a list
    func removePlaceFromList(listId: String, placeId: String) async throws {
        try await userService.removePlaceFromList(listId: listId, placeId: placeId)
    }
    
    /// Fetch places for a specific place list (pagination support)
    func fetchPlacesForPlaceList(listId: String, page: Int = 1, pageSize: Int = 6) async throws -> [LightweightPlace] {
        return try await userService.fetchPlacesForPlaceList(listId: listId, page: page, pageSize: pageSize)
    }
    
    /// Load more places for a list (pagination) and update placeSavers
    /// Returns the loaded places for the caller to use
    func loadMorePlacesForList(listId: String, page: Int, pageSize: Int = 6) async throws -> [LightweightPlace] {
        let places = try await userService.fetchPlacesForPlaceList(listId: listId, page: page, pageSize: pageSize)
        
        await MainActor.run {
            // Append to existing places
            if var existingPlaces = profileViewModel.lightweightPlaceListPlaces[listId] {
                existingPlaces.append(contentsOf: places)
                profileViewModel.lightweightPlaceListPlaces[listId] = existingPlaces
            } else {
                profileViewModel.lightweightPlaceListPlaces[listId] = places
            }
            
            // Update placeSavers for the current user so "Saved By" feature works
            guard let currentUserId = self.userSession.currentUserId else { return }
            for place in places {
                let placeId = place.place_id
                if self.detailPlaceViewModel.placeSavers[placeId] == nil {
                    self.detailPlaceViewModel.placeSavers[placeId] = [currentUserId]
                } else if !self.detailPlaceViewModel.placeSavers[placeId]!.contains(currentUserId) {
                    self.detailPlaceViewModel.placeSavers[placeId]!.append(currentUserId)
                }
            }
        }
        
        return places
    }
    
    /// Load the first 6 places for each place list (background task)
    func loadPlacesForLightweightList(listId: String) async {
        do {
            let places = try await userService.fetchPlacesForPlaceList(listId: listId, page: 1, pageSize: 6)
            
            await MainActor.run {
                profileViewModel.lightweightPlaceListPlaces[listId] = places
                
                // Update placeSavers for the current user so "Saved By" feature works
                guard let currentUserId = self.userSession.currentUserId else { return }
                for place in places {
                    let placeId = place.place_id
                    if self.detailPlaceViewModel.placeSavers[placeId] == nil {
                        self.detailPlaceViewModel.placeSavers[placeId] = [currentUserId]
                    } else if !self.detailPlaceViewModel.placeSavers[placeId]!.contains(currentUserId) {
                        self.detailPlaceViewModel.placeSavers[placeId]!.append(currentUserId)
                    }
                }
            }
        } catch {
            print("❌ [DataManager] Error loading places for list \(listId): \(error.localizedDescription)")
        }
    }
    
    private func loadPlacesForLists(_ lists: [LightweightPlaceList]) async {
        // Load all places in parallel, then batch update on main thread
        var allPlaces: [String: [LightweightPlace]] = [:]
        
        await withTaskGroup(of: (String, [LightweightPlace]?).self) { group in
            for list in lists {
                group.addTask {
                    do {
                        let places = try await self.userService.fetchPlacesForPlaceList(listId: list.list_id, page: 1, pageSize: 6)
                        return (list.list_id, places)
                    } catch {
                        print("❌ [DataManager] Error loading places for list \(list.list_id): \(error.localizedDescription)")
                        return (list.list_id, nil)
                    }
                }
            }
            
            for await (listId, places) in group {
                if let places = places {
                    allPlaces[listId] = places
                }
            }
        }
        
        // Prefetch TikTok metadata for all TikTok URLs
        let allTiktokUrls = allPlaces.values.flatMap { $0.compactMap { $0.tiktok_url } }.filter { !$0.isEmpty }
        if !allTiktokUrls.isEmpty {
            Task {
                await TikTokMetadataCache.shared.prefetchMetadata(for: Array(allTiktokUrls))
            }
        }
        
        // Single main thread update - prevents multiple view re-renders
        // Also update placeSavers for the current user so "Saved By" feature works
        await MainActor.run {
            guard let currentUserId = self.userSession.currentUserId else { return }
            
            for (listId, places) in allPlaces {
                profileViewModel.lightweightPlaceListPlaces[listId] = places
                
                // Update placeSavers for each place in the list
                for place in places {
                    let placeId = place.place_id
                    if self.detailPlaceViewModel.placeSavers[placeId] == nil {
                        self.detailPlaceViewModel.placeSavers[placeId] = [currentUserId]
                    } else if !self.detailPlaceViewModel.placeSavers[placeId]!.contains(currentUserId) {
                        self.detailPlaceViewModel.placeSavers[placeId]!.append(currentUserId)
                    }
                }
            }
            
            // Mark data as freshly loaded for staleness tracking
            profileViewModel.markListPlacesAsRefreshed()
            
            print("📍 [DataManager] Updated placeSavers with \(allPlaces.values.flatMap { $0 }.count) places from lists")
            print("📍 [DataManager] Total placeSavers count: \(self.detailPlaceViewModel.placeSavers.count)")
        }
    }
    
    // MARK: - List Places Refresh
    
    /// Refreshes list places data if stale, fetching fresh data from database
    /// This ensures `latest_review_photo` and other fields reflect current database state
    /// - Parameter forceRefresh: If true, refreshes regardless of staleness
    func refreshListPlacesIfNeeded(forceRefresh: Bool = false) async {
        // Skip if already refreshing
        guard !profileViewModel.isRefreshingListPlaces else {
            print("⏭️ [DataManager] Skipping refresh - already in progress")
            return
        }
        
        // Skip if data is fresh (unless forced)
        guard forceRefresh || profileViewModel.isListPlacesDataStale else {
            print("✅ [DataManager] List places data is fresh, skipping refresh")
            return
        }
        
        // Get visible lists to refresh
        let listsToRefresh = profileViewModel.lightweightPlaceLists
        guard !listsToRefresh.isEmpty else {
            print("⏭️ [DataManager] No lists to refresh")
            return
        }
        
        await MainActor.run {
            profileViewModel.setListPlacesRefreshing(true)
        }
        
        print("🔄 [DataManager] Refreshing list places data for \(listsToRefresh.count) lists")
        
        // Re-fetch places for all lists (reuses existing parallel loading logic)
        await loadPlacesForLists(listsToRefresh)
        
        await MainActor.run {
            profileViewModel.markListPlacesAsRefreshed()
            profileViewModel.setListPlacesRefreshing(false)
        }
        
        print("✅ [DataManager] List places refresh complete")
    }
    
    // Loads all places the user has reviewed, even if not in favorites or lists
    func loadUserReviewedPlaces(userId: String) async {
        do {
            // Fetch all reviews (RestaurantReview and GenericReview) in parallel
            async let restaurantReviews: [RestaurantReview] = try await reviewService.fetchUserReviews(userId: userId)
            async let genericReviews: [GenericReview] = try await reviewService.fetchUserGenericReviews(userId: userId)
            
            let allReviews: [ReviewProtocol] = (try await restaurantReviews) + (try await genericReviews)

            // Sort reviews by timestamp (most recent first) and get unique place IDs while preserving order
            let sortedReviews = allReviews.sorted { $0.timestamp > $1.timestamp }

            // Get unique place IDs while preserving the order of most recently reviewed places
            var seenPlaceIds = Set<String>()
            let placeIds: [String] = sortedReviews.compactMap { review in
                if seenPlaceIds.contains(review.placeId) {
                    return nil
                }
                seenPlaceIds.insert(review.placeId)
                return review.placeId
            }
            
            // Note: Reviewed places are now loaded via server-side pagination
            // This legacy method is kept for compatibility but reviews are managed by ProfileViewModel

            // Process place details in batches
            let batchSize = 10
            
            for batch in placeIds.chunked(into: batchSize) {
                await withTaskGroup(of: Void.self) { group in
                    for placeId in batch {
                        group.addTask {
                            await self.processReviewedPlace(placeId: placeId, userId: userId)
                        }
                    }
                }
            }
        } catch {
            print("Error loading user reviewed places: \(error.localizedDescription)")
        }
    }
    
    private func processReviewedPlace(placeId: String, userId: String) async {
        // Add userId to placeSavers if not already present
        await MainActor.run {
            if self.detailPlaceViewModel.placeSavers[placeId] == nil {
                self.detailPlaceViewModel.placeSavers[placeId] = [userId]
            } else if !self.detailPlaceViewModel.placeSavers[placeId]!.contains(userId) {
                self.detailPlaceViewModel.placeSavers[placeId]!.append(userId)
            }
        }
        
        // Fetch and store the place if not already present
        let hasExistingPlace = await MainActor.run {
            return self.detailPlaceViewModel.places[placeId] != nil
        }
        if !hasExistingPlace {
            do {
                let detailPlace = try await placeService.fetchPlace(withId: placeId)
                await MainActor.run {
                    self.detailPlaceViewModel.places[placeId] = detailPlace
                    // ✅ REMOVED: fetchPlaceImage() - let images load lazily when views appear
                    // self.detailPlaceViewModel.fetchPlaceImage(for: placeId)
                }
            } catch {
                print("Error fetching place for reviewed placeId \(placeId): \(error.localizedDescription)")
            }
        }
    }
    
    
    // Loads all reviewed places for the current user and their following
    func loadReviewedPlacesForUserAndFollowing(userId: String) async {
        let followingIds = profileViewModel.userFollowing.map { $0.id }
        let allUserIds = followingIds + [userId]
        for uid in allUserIds {
            await loadUserReviewedPlaces(userId: uid)
        }
    }
    
    // MARK: - Public Accessors
    
    /// Get external places for a specific place ID
    func getExternalPlace(for placeId: String) -> ExternalPlace? {
        return profileViewModel.userExternalPlaces[placeId]
    }
    
    /// Get all external places
    func getAllExternalPlaces() -> [String: ExternalPlace] {
        return profileViewModel.userExternalPlaces
    }
}

