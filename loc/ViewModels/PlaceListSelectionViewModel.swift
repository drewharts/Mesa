//
//  PlaceListSelectionViewModel.swift
//  loc
//
//  Created by Cursor on 3/1/25.
//  ViewModel responsible for "Save to List" flow
//

import Foundation
import CoreLocation

@MainActor
class PlaceListSelectionViewModel: ObservableObject {
    // MARK: - Published State (Own Pagination)
    @Published var lists: [LightweightPlaceList] = []
    @Published var isLoadingInitial: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var hasMore: Bool = true
    
    // MARK: - Dependencies
    private let profile: ProfileViewModel
    private let userService: UserService
    private let userSession: UserSession
    private let placeService: SupabasePlaceService
    private let dataManager: DataManager
    
    // MARK: - Internal State
    private var placeCoordinates: CLLocationCoordinate2D?
    private var currentPage: Int = 1
    private let pageSize: Int = 6
    private var hasLoadedOnce: Bool = false
    
    // MARK: - Init
    init(profile: ProfileViewModel,
         userService: UserService,
         userSession: UserSession,
         dataManager: DataManager,
         placeService: SupabasePlaceService = SupabasePlaceService.shared) {
        self.profile = profile
        self.userService = userService
        self.userSession = userSession
        self.dataManager = dataManager
        self.placeService = placeService
        print("🆕 [PlaceListSelectionVM] ViewModel initialized")
    }
    
    deinit {
        print("🗑️ [PlaceListSelectionVM] ViewModel deallocated")
    }
    
    // MARK: - Public API
    
    func loadInitialLists(for place: DetailPlace) async {
        guard let userId = userSession.currentUserId,
              let coord = place.coordinate else { return }
        
        // Guard: Don't reload if we already have lists loaded
        // This prevents .task from wiping out paginated lists when view re-renders
        if hasLoadedOnce && !lists.isEmpty {
            print("ℹ️ [PlaceListSelectionVM] Lists already loaded (\(lists.count) lists), skipping reload")
            return
        }
        
        // Reset state for new place
        placeCoordinates = coord
        currentPage = 1
        hasMore = true
        isLoadingInitial = true
        
        do {
            let fetchedLists = try await userService.fetchPlaceListsByProximity(
                userId: userId,
                userLatitude: coord.latitude,
                userLongitude: coord.longitude,
                page: 1,
                pageSize: pageSize
            )
            
            lists = fetchedLists
            hasMore = fetchedLists.count >= pageSize
            hasLoadedOnce = true
            
            print("✅ [PlaceListSelectionVM] Loaded \(fetchedLists.count) lists for place at (\(coord.latitude), \(coord.longitude))")
            
            // Load place membership data for each list (so we can show checkmarks)
            if !fetchedLists.isEmpty {
                await loadPlaceMembershipForLists(fetchedLists)
            }
        } catch {
            print("❌ [PlaceListSelectionVM] Error loading lists: \(error)")
            lists = []
            hasMore = false
        }
        
        isLoadingInitial = false
    }
    
    func loadMoreListsIfNeeded(currentIndex: Int) async {
        // Guard: Already loading or no more to load
        guard !isLoadingMore,
              hasMore,
              let coord = placeCoordinates,
              let userId = userSession.currentUserId else { return }
        
        // Don't load if we're not near the end
        guard currentIndex >= lists.count - 3 else { return }
        
        isLoadingMore = true
        let nextPage = currentPage + 1
        
        print("📄 [PlaceListSelectionVM] Loading page \(nextPage) of lists...")
        
        do {
            let moreLists = try await userService.fetchPlaceListsByProximity(
                userId: userId,
                userLatitude: coord.latitude,
                userLongitude: coord.longitude,
                page: nextPage,
                pageSize: pageSize
            )
            
            if !moreLists.isEmpty {
                lists.append(contentsOf: moreLists)
                currentPage = nextPage
                hasMore = moreLists.count >= pageSize
                print("✅ [PlaceListSelectionVM] Added \(moreLists.count) more lists. Total: \(lists.count)")
                
                // Load place membership data for new lists
                await loadPlaceMembershipForLists(moreLists)
            } else {
                hasMore = false
                print("ℹ️ [PlaceListSelectionVM] No more lists available")
            }
        } catch {
            print("❌ [PlaceListSelectionVM] Error loading more lists: \(error)")
            // Don't set hasMore to false on error - allow retry
        }
        
        isLoadingMore = false
    }
    
    // MARK: - Private Helpers
    
    /// Load place membership data for lists (so we can show checkmarks)
    private func loadPlaceMembershipForLists(_ listsToLoad: [LightweightPlaceList]) async {
        print("📋 [PlaceListSelectionVM] Loading place membership for \(listsToLoad.count) lists...")
        
        // Load places for each list in parallel
        await withTaskGroup(of: (String, [LightweightPlace]?).self) { group in
            for list in listsToLoad {
                group.addTask {
                    do {
                        let places = try await self.userService.fetchPlacesForPlaceList(
                            listId: list.list_id,
                            page: 1,
                            pageSize: 6
                        )
                        return (list.list_id, places)
                    } catch {
                        print("❌ [PlaceListSelectionVM] Error loading places for list \(list.list_id): \(error)")
                        return (list.list_id, nil)
                    }
                }
            }
            
            // Collect all results
            var allPlaces: [String: [LightweightPlace]] = [:]
            for await (listId, places) in group {
                if let places = places {
                    allPlaces[listId] = places
                }
            }
            
            // Single main thread update to prevent multiple re-renders
            await MainActor.run {
                for (listId, places) in allPlaces {
                    profile.lightweightPlaceListPlaces[listId] = places
                }
            }
        }
        
        print("✅ [PlaceListSelectionVM] Finished loading place membership for all lists")
    }
    
    func isPlace(_ place: DetailPlace, in list: LightweightPlaceList) -> Bool {
        profile.lightweightPlaceListPlaces[list.list_id]?
            .contains(where: { $0.place_id == place.id.uuidString }) ?? false
    }
    
    func toggle(place: DetailPlace, in list: LightweightPlaceList) {
        if isPlace(place, in: list) {
            profile.removePlaceFromLightweightList(listId: list.list_id, place: place)
        } else {
            profile.addPlaceToLightweightList(listId: list.list_id, place: place)
        }
    }
    
    func createNewList(named name: String, city: String, emoji: String, image: String) async {
        guard let userId = userSession.currentUserId else { return }
        
        do {
            let createdList = try await placeService.createNewList(
                userId: userId,
                name: name,
                city: city,
                emoji: emoji,
                image: image
            )
            
            // Add new list to top of our own lists array
            let lightweightList = LightweightPlaceList(
                list_id: createdList.id.uuidString,
                name: createdList.name,
                is_public: false,
                image: createdList.image,
                created_at: ISO8601DateFormatter().string(from: Date()),
                updated_at: ISO8601DateFormatter().string(from: Date()),
                distance_meters: nil,
                place_count: 0,
                city: nil
            )
            
            lists.insert(lightweightList, at: 0)
            
            // Also update ProfileViewModel for other parts of the app
            profile.lightweightPlaceLists.insert(lightweightList, at: 0)
            profile.userLists.append(createdList)
            profile.recentlyCreatedListId = createdList.id
            
            print("✅ [PlaceListSelectionVM] Created new list: \(name)")
        } catch {
            print("❌ [PlaceListSelectionVM] Error creating list: \(error)")
        }
    }
}

