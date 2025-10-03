//
//  DataManager.swift
//  loc
//
//  Created by Andrew Hartsfield II on 4/29/25.
//

import Foundation
import FirebaseAuth
import UIKit

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

    func initializeProfileData(userId: String) async {
        startDataLoadingFlags()
        
        // PHASE 1: Load critical user data in parallel (fastest to show something to user)
        await loadCriticalUserData(userId: userId)
        
        // PHASE 2: Load remaining user data in parallel
        await loadRemainingUserData(userId: userId)
        
        // PHASE 3: Load social data in background (non-blocking)
        Task.detached { [weak self] in
            await self?.loadSocialDataInBackground(userId: userId)
        }
        
        calculateMapAnnotations()
    }
    
    // PHASE 1: Load most important user data first (parallel)
    private func loadCriticalUserData(userId: String) async {
        async let profileData: () = loadProfileData(userId: userId)
        async let myPlaces: () = loadUserMyPlaces(userId: userId)
        async let favorites: () = loadUserFavoritePlaces(userId: userId)
        
        // Wait for critical data to complete
        await profileData
        await myPlaces
        await favorites
    }
    
    // PHASE 2: Load remaining user data (parallel)
    private func loadRemainingUserData(userId: String) async {
        async let placeLists: () = loadUserPlaceLists(userId: userId)
        async let reviewedPlaces: () = loadUserReviewedPlaces(userId: userId)
        async let followCounts: () = fetchFollowerAndFollowingCountsAsync(userId: userId)
        async let externalPlaces: () = loadUserExternalPlaces(userId: userId)
        
        // Wait for remaining user data
        await placeLists
        await reviewedPlaces
        await followCounts
        await externalPlaces
    }
    
    // PHASE 3: Load social data without blocking UI
    private func loadSocialDataInBackground(userId: String) async {
        async let following: () = loadFollowing(userId: userId)
        async let followers: () = loadFollowers(userId: userId)
        
        // Wait for social connections
        await following
        await followers
        
        // Load reviewed places for following users
        await loadReviewedPlacesForFollowing(userId: userId)
        
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
        detailPlaceViewModel.calculateAnnotationPlaces()
    }
    
    func loadUserMyPlaces(userId: String) async {
        profileViewModel.isMyPlacesLoading = true
        do {
            let places = try await placeService.fetchMyPlaces(userId: userId)
            for place in places {
                self.profileViewModel.myPlaces.append(place.id.uuidString)
                self.detailPlaceViewModel.places[place.id.uuidString] = place
                self.detailPlaceViewModel.fetchPlaceImage(for: place.id.uuidString)
                // Add the current user as a saver for their own place
                let placeId = place.id.uuidString
                if self.detailPlaceViewModel.placeSavers[placeId] == nil {
                    self.detailPlaceViewModel.placeSavers[placeId] = [userId]
                } else if !self.detailPlaceViewModel.placeSavers[placeId]!.contains(userId) {
                    self.detailPlaceViewModel.placeSavers[placeId]!.append(userId)
                }
            }
        } catch {
            print("Error loading my places: \(error.localizedDescription)")
        }
        profileViewModel.isMyPlacesLoading = false
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
            profileViewModel.userExternalPlaces = externalPlaces
            
            // Note: DetailPlace objects will be loaded via pagination when TikTok tab is accessed
            
        } catch {
            print("❌ [DataManager] Error loading external places: \(error.localizedDescription)")
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
        downloadImage(from: profilePhotoUrl) { image in
            if let image = image {
                if isCurrentUser {
                    self.profileViewModel.userPicture = image
                }
                self.detailPlaceViewModel.userProfilePicture[userId] = image
                self.detailPlaceViewModel.calculateAnnotationPlaces()
            } else {
                print("Failed to download profile picture from URL: \(profilePhotoUrl)")
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
            let lists = try await placeService.fetchLists(userId: userId)
            // If this is for the current user, update the ProfileViewModel
            if forUser == nil {
                self.profileViewModel.userLists = lists
                // Initialize with empty place arrays for lazy loading
                self.profileViewModel.userListsPlaces = lists.reduce(into: [String: [String]]()) { result, list in
                    result[list.id.uuidString] = []
                }
                // Sort lists by distance after loading
                self.profileViewModel.sortListsByDistance()
            }
            // Note: Places will be loaded lazily when lists become visible
            // No need to process all places upfront
        } catch {
            print("Error loading user place lists: \(error.localizedDescription)")
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
        
        // Process in batches to avoid overwhelming Firebase
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
            print("Error fetching place details: \(error.localizedDescription) (listId: \(listId), placeId: \(placeId))")
            
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
    
    func loadFollowing(userId: String) async {
        profileViewModel.isFollowingListLoading = true
        do {
            let profiles = try await userService.fetchFollowingProfilesData(for: userId)
            // Store the profiles in the profileViewModel
            self.profileViewModel.userFollowing = profiles
            
            // Load profile pictures first (quick)
            for profile in profiles {
                if let profilePhotoURL = profile.profilePhotoURL {
                    self.AddProfilePicture(userId: profile.id, profilePhotoUrl: profilePhotoURL)
                }
            }
            
            // Load places data for following users in background with limited concurrency
            await loadFollowingPlacesDataOptimized(profiles: profiles)
        } catch {
            print("Error loading following profiles: \(error.localizedDescription)")
        }
        profileViewModel.isFollowingListLoading = false
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

    
    func loadFollowers(userId: String) async {
        profileViewModel.isFollowersListLoading = true
        do {
            let profiles = try await userService.fetchFollowerProfilesData(for: userId)
            // Store the profiles in the profileViewModel
            self.profileViewModel.userFollowers = profiles
        } catch {
            print("Error loading followers: \(error.localizedDescription)")
        }
        profileViewModel.isFollowersListLoading = false
    }
    
    func fetchFollowerAndFollowingCountsAsync(userId: String) async {
        profileViewModel.isFollowersLoading = true
        profileViewModel.isFollowingLoading = true
        async let followers: Int = try! await userService.getNumberFollowers(forUserId: userId)
        async let following: Int = try! await userService.getNumberFollowing(forUserId: userId)
        let (followersCount, followingCount) = await (followers, following)
        profileViewModel.followersCount = followersCount
        profileViewModel.followingCount = followingCount
        profileViewModel.isFollowersLoading = false
        profileViewModel.isFollowingLoading = false
    }
    
    // Loads all places the user has reviewed, even if not in favorites or lists
    func loadUserReviewedPlaces(userId: String) async {
        do {
            // Fetch all reviews (RestaurantReview and GenericReview) in parallel
            async let restaurantReviews: [RestaurantReview] = try await reviewService.fetchUserReviews(userId: userId)
            async let genericReviews: [GenericReview] = try await reviewService.fetchUserReviews(userId: userId)
            
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
                    self.detailPlaceViewModel.fetchPlaceImage(for: placeId)
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

