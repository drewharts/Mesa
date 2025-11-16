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
    
    // MARK: - Internal State
    private var placeCoordinates: CLLocationCoordinate2D?
    private var currentPage: Int = 1
    private let pageSize: Int = 6
    private var hasLoadedOnce: Bool = false
    
    // MARK: - Init
    init(profile: ProfileViewModel,
         userService: UserService,
         userSession: UserSession) {
        self.profile = profile
        self.userService = userService
        self.userSession = userSession
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
}

