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
    weak var placeTypeFilterViewModel: PlaceTypeFilterViewModel?
    
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
        let startTime = CFAbsoluteTimeGetCurrent()
        print("🚀 [DataManager] Starting MINIMAL profile data initialization")
        
        startDataLoadingFlags()
        
        // ✅ PHASE 1: Load ONLY essential data for immediate UI display
        await measureLoadingTime("Essential Data") {
            await loadEssentialDataOnly(userId: userId)
        }
        
        // ✅ PHASE 2: Load viewport places in background (non-blocking)
        Task.detached { [weak self] in
            await self?.measureLoadingTime("Viewport Places") {
                await self?.loadViewportPlacesOnly(userId: userId)
            }
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        print("✅ [DataManager] Essential data loaded in \(String(format: "%.2f", endTime - startTime))s - UI ready!")
    }
    
    /// Helper to measure loading time for performance monitoring
    private func measureLoadingTime<T>(_ operation: String, block: () async throws -> T) async rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = try await block()
        let end = CFAbsoluteTimeGetCurrent()
        print("⏱️ [DataManager] \(operation) took \(String(format: "%.2f", end - start))s")
        return result
    }
    
    /// Load essential user profile data and all place annotations at startup
    /// Uses the optimized PostgreSQL function to get user + friends' places in one call
    private func loadEssentialDataOnly(userId: String) async {
        // Load essential profile data in parallel
        async let profileData: () = loadProfileData(userId: userId)
        async let followingIds: () = loadFollowingUserIds(userId: userId)
        
        // Wait for essential data to complete
        await profileData
        await followingIds
        
        print("✅ [DataManager] Essential profile data loaded - UI ready for interaction!")
        
        // Reset loading flags since we're not loading follower/following profiles yet
        await MainActor.run {
            profileViewModel.isFollowersListLoading = false
            profileViewModel.isFollowingListLoading = false
        }
        
        // Note: Counts (followers/following/myplaces) are loaded on-demand when profile view appears
        // Note: Place annotations are now loaded on-demand via viewport queries
        // No need to preload all annotations - the MapViewModel handles this
    }
    
    /// Load following user IDs only (not full profiles)
    private func loadFollowingUserIds(userId: String) async {
        do {
            let followingIds = try await userService.fetchFollowingUserIds(userId: userId)
            await MainActor.run {
                // Store just the IDs for viewport filtering
                self.profileViewModel.userFollowing = followingIds.map { ProfileData(id: $0, firstName: "", lastName: "", email: "", profilePhotoURL: nil, phoneNumber: "", fullNameLower: "", fullName: "", fcmToken: nil, firebaseUid: nil, supabaseUid: nil) }
                print("✅ [DataManager] Loaded \(followingIds.count) following user IDs")
                // Note: Friend tracking is now handled by PostgreSQL function - no need to update MapViewModel
            }
        } catch {
            print("❌ [DataManager] Error loading following user IDs: \(error.localizedDescription)")
        }
    }
    
    /// Load place IDs only (not full place documents) - MUCH faster!
    private func loadUserPlaceIdsOnly(userId: String) async {
        do {
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
                
                print("✅ [DataManager] Loaded place IDs only:")
                print("   - Favorites: \(favIds?.count ?? 0)")
                print("   - My Places: \(myPlaceIdsResult?.count ?? 0)")
                print("   - Lists: \(listMetadataResult?.count ?? 0)")
            }
        } catch {
            print("❌ [DataManager] Error loading place IDs: \(error.localizedDescription)")
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
            // ✅ Use the correct user ID (profile ID, not Supabase auth UID)
            let viewportPlaces = try await placeService.fetchPlacesInViewportWithUserId(
                northLat: bounds.northLat,
                southLat: bounds.southLat,
                eastLng: bounds.eastLng,
                westLng: bounds.westLng,
                userId: userId
            )
            
            await MainActor.run {
                // Note: viewportPlaces now returns PlaceAnnotation objects, not DetailPlace
                // These are lightweight annotations for map display only
                // Full place details are loaded on-demand when user taps markers
                let duration = Date().timeIntervalSince(startTime)
                print("⚡ [DataManager] Loaded \(viewportPlaces.count) place annotations in \(String(format: "%.2f", duration))s")
            }
            
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
            
            // Force update of filtered places for map display
            await MainActor.run {
                if let placeTypeFilterVM = self.placeTypeFilterViewModel {
                    placeTypeFilterVM.updateFilteredPlaces()
                    print("🗺️ [DataManager] Forced filteredPlaces update, now showing: \(placeTypeFilterVM.filteredPlaces.count) places")
                }
            }
            
        } catch {
            print("❌ [DataManager] Error loading all user places: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Data Loading Methods
    
    /// Load social data in background (follower/following profiles)
    private func loadSocialDataInBackground(userId: String) async {
        print("💤 [DataManager] Loading follower/following profiles in background...")
        
        // Reset the list loading flags since we're loading profiles here
        await MainActor.run {
            profileViewModel.isFollowersListLoading = false
            profileViewModel.isFollowingListLoading = false
            print("✅ [DataManager] Reset follower/following list loading flags to false")
        }
        
        // Only load reviewed places for following users if we already have the following list
        if !profileViewModel.userFollowing.isEmpty {
            await loadReviewedPlacesForFollowing(userId: userId)
        }
        
        // Update annotations after social data loads
        await MainActor.run {
            calculateMapAnnotations()
        }
    }

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
    
    func loadUserMyPlaces(userId: String) async {
        profileViewModel.isMyPlacesLoading = true
        do {
            let places = try await placeService.fetchMyPlaces(userId: userId)
            
            // Clear existing myPlaces and set new ones (avoid duplicates)
            self.profileViewModel.myPlaces = places.map { $0.id.uuidString }
            
            for place in places {
                self.detailPlaceViewModel.places[place.id.uuidString] = place
                // ✅ REMOVED: fetchPlaceImage() - let images load lazily when views appear
                // self.detailPlaceViewModel.fetchPlaceImage(for: place.id.uuidString)
                // Add the current user as a saver for their own place
                let placeId = place.id.uuidString
                if self.detailPlaceViewModel.placeSavers[placeId] == nil {
                    self.detailPlaceViewModel.placeSavers[placeId] = [userId]
                } else if !self.detailPlaceViewModel.placeSavers[placeId]!.contains(userId) {
                    self.detailPlaceViewModel.placeSavers[placeId]!.append(userId)
                }
            }
            
            print("✅ [DataManager] Loaded \(places.count) myPlaces for user: \(userId)")
        } catch {
            print("❌ [DataManager] Error loading my places: \(error.localizedDescription)")
        }
        profileViewModel.isMyPlacesLoading = false
    }
    
    /// Refresh My Places data (for when user clicks on My Places)
    func refreshMyPlaces(userId: String) async {
        print("🔄 [DataManager] Refreshing My Places data...")
        // Clear existing data and reload
        profileViewModel.myPlaces.removeAll()
        await loadUserMyPlaces(userId: userId)
    }
    
    /// Refresh Reviewed Places data (for when user clicks on My Places)
    func refreshReviewedPlaces(userId: String) async {
        print("🔄 [DataManager] Refreshing Reviewed Places data...")
        // Clear existing data and reload
        profileViewModel.allReviewedPlaceIds.removeAll()
        await loadUserReviewedPlaces(userId: userId)
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
    
    // Load user's external places (TikTok-sourced places)
    func loadUserExternalPlaces(userId: String) async {
        do {
            let externalPlaces = try await userService.fetchUserExternalPlaces(userId: userId)
            // Convert array to dictionary with place IDs as keys
            let externalPlacesDict = Dictionary(uniqueKeysWithValues: externalPlaces.map { ($0.placeId, $0) })
            profileViewModel.userExternalPlaces = externalPlacesDict
            
            // Note: DetailPlace objects will be loaded via pagination when TikTok tab is accessed
            
        } catch {
            print("❌ [DataManager] Error loading external places: \(error.localizedDescription)")
        }
    }
    
    /// Load all places from people the user follows (saved, reviewed, imported from TikTok)
    /// This is essential for social discovery and should load in background after essential data
    private func loadFollowingUsersPlaces(userId: String) async {
        let startTime = Date()
        print("👥 [DataManager] Loading all places from people user follows...")
        
        // Get the following user IDs (should already be loaded)
        let followingIds = profileViewModel.userFollowing.map { $0.id }
        
        guard !followingIds.isEmpty else {
            print("👥 [DataManager] No following users to load places from")
            return
        }
        
        print("👥 [DataManager] Loading places from \(followingIds.count) following users...")
        
        do {
            // Load all places from each following user in parallel
            var allFollowingPlaces: [DetailPlace] = []
            var placeSavers: [String: [String]] = [:] // Track who saved each place
            
            // Process following users in batches to avoid overwhelming the database
            let batchSize = 5
            for i in stride(from: 0, to: followingIds.count, by: batchSize) {
                let batch = Array(followingIds[i..<min(i + batchSize, followingIds.count)])
                
                // Load places for this batch in parallel
                let batchResults = await withTaskGroup(of: (String, [DetailPlace]).self) { group in
                    for followingId in batch {
                        group.addTask {
                            do {
                                let places = try await self.placeService.fetchAllUserPlaces(userId: followingId)
                                return (followingId, places)
                            } catch {
                                print("❌ [DataManager] Error loading places for following user \(followingId): \(error.localizedDescription)")
                                return (followingId, [])
                            }
                        }
                    }
                    
                    var results: [(String, [DetailPlace])] = []
                    for await result in group {
                        results.append(result)
                    }
                    return results
                }
                
                // Process batch results
                for (followingId, places) in batchResults {
                    allFollowingPlaces.append(contentsOf: places)
                    
                    // Track who saved each place
                    for place in places {
                        let placeId = place.id.uuidString
                        if placeSavers[placeId] == nil {
                            placeSavers[placeId] = [followingId]
                        } else if !placeSavers[placeId]!.contains(followingId) {
                            placeSavers[placeId]!.append(followingId)
                        }
                    }
                }
            }
            
            // Update the DetailPlaceViewModel with all following users' places
            await MainActor.run {
                for place in allFollowingPlaces {
                    let placeId = place.id.uuidString
                    self.detailPlaceViewModel.places[placeId] = place
                    self.detailPlaceViewModel.generateColorForPlace(placeId)
                    self.detailPlaceViewModel.calculateRestaurantType(for: place)
                }
                
                // Update place savers information
                for (placeId, savers) in placeSavers {
                    if self.detailPlaceViewModel.placeSavers[placeId] == nil {
                        self.detailPlaceViewModel.placeSavers[placeId] = savers
                    } else {
                        // Merge with existing savers, avoiding duplicates
                        let existingSavers = Set(self.detailPlaceViewModel.placeSavers[placeId] ?? [])
                        let newSavers = Set(savers)
                        self.detailPlaceViewModel.placeSavers[placeId] = Array(existingSavers.union(newSavers))
                    }
                }
                
                let duration = Date().timeIntervalSince(startTime)
                print("✅ [DataManager] Loaded \(allFollowingPlaces.count) places from \(followingIds.count) following users in \(String(format: "%.2f", duration))s")
                print("👥 [DataManager] Updated placeSavers for \(placeSavers.count) unique places")
                
                // Force update of filtered places for map display
                if let placeTypeFilterVM = self.placeTypeFilterViewModel {
                    placeTypeFilterVM.updateFilteredPlaces()
                    print("🗺️ [DataManager] Forced filteredPlaces update after loading friends' places, now showing: \(placeTypeFilterVM.filteredPlaces.count) places")
                }
            }
            
        } catch {
            print("❌ [DataManager] Error loading following users' places: \(error.localizedDescription)")
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
                print("✅ [DataManager] Marked list '\(list.name)' as preloaded")
            }
        }
        
        print("✅ [DataManager] Finished preloading places for first \(sortedLists.count) lists")
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
        let startTime = Date()
        
        if isInitialLoad {
            print("👥 [DataManager] Loading first 10 following profiles...")
        } else {
            print("👥 [DataManager] Loading next 10 following profiles (offset: \(offset))...")
        }
        
        profileViewModel.isFollowingListLoading = true
        
        do {
            let profiles = try await userService.fetchFollowingProfilesData(for: userId, limit: 10, offset: offset)
            
            let duration = Date().timeIntervalSince(startTime)
            print("⚡ [DataManager] Loaded \(profiles.count) following profiles in \(String(format: "%.2f", duration))s")
            
            await MainActor.run {
                if isInitialLoad {
                    self.profileViewModel.userFollowing = profiles
                } else {
                    self.profileViewModel.userFollowing.append(contentsOf: profiles)
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
        let startTime = Date()
        
        if isInitialLoad {
            print("👥 [DataManager] Loading first 10 follower profiles...")
        } else {
            print("👥 [DataManager] Loading next 10 follower profiles (offset: \(offset))...")
        }
        
        profileViewModel.isFollowersListLoading = true
        
        do {
            let profiles = try await userService.fetchFollowerProfilesData(for: userId, limit: 10, offset: offset)
            
            let duration = Date().timeIntervalSince(startTime)
            print("⚡ [DataManager] Loaded \(profiles.count) follower profiles in \(String(format: "%.2f", duration))s")
            
            await MainActor.run {
                if isInitialLoad {
                    self.profileViewModel.userFollowers = profiles
                } else {
                    self.profileViewModel.userFollowers.append(contentsOf: profiles)
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
    
    /// FAST: Load all profile counts (followers/following/myplaces) in parallel (~20-50ms total!)
    /// Called when profile view appears
    func loadProfileCounts(userId: String) async {
        let startTime = Date()
        print("🔢 [DataManager] Loading profile COUNTS (fast)...")
        
        profileViewModel.isFollowersLoading = true
        profileViewModel.isFollowingLoading = true
        profileViewModel.isMyPlacesLoading = true
        
        // Run all three count queries in parallel
        async let followers: Int = (try? await userService.getNumberFollowers(forUserId: userId)) ?? 0
        async let following: Int = (try? await userService.getNumberFollowing(forUserId: userId)) ?? 0
        async let myPlaces: Int = (try? await userService.getNumberMyPlaces(forUserId: userId)) ?? 0
        
        let (followersCount, followingCount, myPlacesCount) = await (followers, following, myPlaces)
        
        profileViewModel.followersCount = followersCount
        profileViewModel.followingCount = followingCount
        // Update my places count - we'll store this as the count of myPlaces array
        profileViewModel.myPlaces = Array(repeating: "", count: myPlacesCount) // Placeholder IDs
        profileViewModel.isFollowersLoading = false
        profileViewModel.isFollowingLoading = false
        profileViewModel.isMyPlacesLoading = false
        
        let duration = Date().timeIntervalSince(startTime)
        print("⚡ [DataManager] Loaded counts in \(String(format: "%.2f", duration))s (Followers: \(followersCount), Following: \(followingCount), My Places: \(myPlacesCount))")
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
            
            // Update the ProfileViewModel with the reviewed place IDs for count display
            await MainActor.run {
                profileViewModel.allReviewedPlaceIds = placeIds
            }

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
    
    // Loads reviewed places only for following users (separated from main user)
    private func loadReviewedPlacesForFollowing(userId: String) async {
        let followingIds = profileViewModel.userFollowing.map { $0.id }
        
        // Process following users in batches
        let batchSize = 3
        for batch in followingIds.chunked(into: batchSize) {
            await withTaskGroup(of: Void.self) { group in
                for uid in batch {
                    group.addTask {
                        await self.loadUserReviewedPlaces(userId: uid)
                    }
                }
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

