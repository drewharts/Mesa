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
    @Published var placeMembership: [String: Bool] = [:] // listId -> isPlaceInList
    
    // MARK: - Dependencies
    private let profile: ProfileViewModel
    private let placeListService: PlaceListService
    private let userSession: UserSession
    
    // MARK: - Internal State
    private var placeCoordinates: CLLocationCoordinate2D?
    private var currentPage: Int = 1
    private let pageSize: Int = 10  // Load 10 lists at a time
    private var hasLoadedOnce: Bool = false
    private var currentPlace: DetailPlace?
    
    // MARK: - Init
    init(profile: ProfileViewModel,
         placeListService: PlaceListService = PlaceListService.shared,
         userSession: UserSession) {
        self.profile = profile
        self.placeListService = placeListService
        self.userSession = userSession
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
        currentPlace = place
        placeCoordinates = coord
        currentPage = 1
        hasMore = true
        isLoadingInitial = true
        placeMembership.removeAll()
        
        do {
            let fetchedLists = try await placeListService.fetchListsByProximity(
                userId: userId,
                latitude: coord.latitude,
                longitude: coord.longitude,
                page: 1,
                pageSize: pageSize
            )
            
            lists = fetchedLists
            hasMore = fetchedLists.count >= pageSize
            hasLoadedOnce = true
            
            print("✅ [PlaceListSelectionVM] Loaded \(fetchedLists.count) lists for place at (\(coord.latitude), \(coord.longitude))")
            
            // Load place membership data for each list (so we can show checkmarks)
            if !fetchedLists.isEmpty {
                await loadPlaceMembershipForLists(fetchedLists, placeId: place.id.uuidString)
            }
        } catch {
            print("❌ [PlaceListSelectionVM] Error loading lists: \(error)")
            lists = []
            hasMore = false
        }
        
        isLoadingInitial = false
    }
    
    func loadMoreListsIfNeeded(currentIndex: Int) async {
        // Debug: Log every call to see if pagination is being triggered
        print("🔍 [PlaceListSelectionVM] Pagination check: index=\(currentIndex), count=\(lists.count), isLoadingMore=\(isLoadingMore), hasMore=\(hasMore)")
        
        // Guard: Already loading or no more to load
        guard !isLoadingMore,
              hasMore,
              let coord = placeCoordinates,
              let userId = userSession.currentUserId else {
            print("⛔️ [PlaceListSelectionVM] Pagination blocked by guard")
            return
        }
        
        // Load when we're within 3 items of the end (earlier trigger for smoother UX)
        guard currentIndex >= lists.count - 3 else {
            print("⏭️ [PlaceListSelectionVM] Not near end yet: \(currentIndex) < \(lists.count - 3)")
            return
        }
        
        isLoadingMore = true
        let nextPage = currentPage + 1
        
        print("📄 [PlaceListSelectionVM] Loading page \(nextPage) of lists (triggered at index \(currentIndex) of \(lists.count))...")
        
        do {
            let moreLists = try await placeListService.fetchListsByProximity(
                userId: userId,
                latitude: coord.latitude,
                longitude: coord.longitude,
                page: nextPage,
                pageSize: pageSize
            )
            
            if !moreLists.isEmpty {
                lists.append(contentsOf: moreLists)
                currentPage = nextPage
                hasMore = moreLists.count >= pageSize
                print("✅ [PlaceListSelectionVM] Added \(moreLists.count) more lists. Total: \(lists.count), hasMore=\(hasMore)")
                
                // ✅ CRITICAL FIX: Load place membership data in BACKGROUND (non-blocking)
                // This allows pagination to continue immediately without waiting for checkmarks
                // Follows Single Responsibility: Pagination ≠ Data Enrichment
                if let placeId = currentPlace?.id.uuidString {
                    Task {
                        await loadPlaceMembershipForLists(moreLists, placeId: placeId)
                    }
                }
            } else {
                hasMore = false
                print("ℹ️ [PlaceListSelectionVM] No more lists available")
            }
        } catch {
            print("❌ [PlaceListSelectionVM] Error loading more lists: \(error)")
            // Don't set hasMore to false on error - allow retry
        }
        
        // ✅ CRITICAL: Release lock immediately so next page can load
        isLoadingMore = false
        print("✅ [PlaceListSelectionVM] Pagination complete, ready for next page")
    }
    
    // MARK: - Private Helpers
    
    /// Load place membership data for lists using direct database checks
    /// This checks if the specific place is in each list without loading all places
    private func loadPlaceMembershipForLists(_ listsToLoad: [LightweightPlaceList], placeId: String) async {
        print("📋 [PlaceListSelectionVM] Checking membership for place \(placeId) in \(listsToLoad.count) lists...")
        
        // Check membership for each list in parallel
        await withTaskGroup(of: (String, Bool).self) { group in
            for list in listsToLoad {
                group.addTask {
                    do {
                        let isInList = try await self.placeListService.isPlaceInList(
                            listId: list.list_id,
                            placeId: placeId
                        )
                        return (list.list_id, isInList)
                    } catch {
                        print("❌ [PlaceListSelectionVM] Error checking membership for list \(list.list_id): \(error)")
                        return (list.list_id, false)
                    }
                }
            }
            
            // Collect all results
            var membership: [String: Bool] = [:]
            for await (listId, isInList) in group {
                membership[listId] = isInList
            }
            
            // Single main thread update to prevent multiple re-renders
            await MainActor.run {
                self.placeMembership.merge(membership) { _, new in new }
            }
        }
        
        print("✅ [PlaceListSelectionVM] Finished checking place membership for all lists")
    }
    
    func isPlace(_ place: DetailPlace, in list: LightweightPlaceList) -> Bool {
        return placeMembership[list.list_id] ?? false
    }
    
    func toggle(place: DetailPlace, in list: LightweightPlaceList) {
        let wasInList = isPlace(place, in: list)
        
        if wasInList {
            profile.removePlaceFromLightweightList(listId: list.list_id, place: place)
            // Update local state immediately for UI responsiveness
            placeMembership[list.list_id] = false
        } else {
            profile.addPlaceToLightweightList(listId: list.list_id, place: place)
            // Update local state immediately for UI responsiveness
            placeMembership[list.list_id] = true
        }
    }
    
    func createNewList(named name: String, city: String, emoji: String, image: String) async {
        guard let userId = userSession.currentUserId else { return }
        
        do {
            let createdList = try await placeListService.createList(
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
                    } catch {
            print("❌ [PlaceListSelectionVM] Error creating list: \(error)")
        }
    }
}

