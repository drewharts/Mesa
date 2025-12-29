//
//  PlaceListSelectionViewModel.swift
//  loc
//
//  Created by Cursor on 3/1/25.
//
//  SMART ViewModel: Manages "Save to List" selection flow
//  Single Responsibility: List selection state for adding places to lists
//
//  Features:
//  - Loads OWNED lists (sorted by proximity to place)
//  - Loads SHARED lists (where user is a collaborator)
//  - Tracks which lists already contain the place
//  - Handles pagination for owned lists
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
    
    // MARK: - Filter State
    @Published var showOnlyShared: Bool = false
    @Published var searchText: String = ""
    
    // MARK: - Computed Properties
    
    /// Returns filtered lists based on current filter and search text
    /// Applies shared filter first, then search filter (client-side for instant results)
    var filteredLists: [LightweightPlaceList] {
        var result = lists
        
        // Apply shared filter
        if showOnlyShared {
            result = result.filter { $0.isCollaborative }
        }
        
        // Apply search filter (client-side for instant results)
        if !searchText.isEmpty {
            result = result.filter { list in
                list.name.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return result
    }
    
    /// Count of collaborative lists (shared with you OR you shared with others)
    var collaborativeListCount: Int {
        lists.filter { $0.isCollaborative }.count
    }
    
    /// Whether there are any collaborative lists to filter
    var hasSharedLists: Bool {
        collaborativeListCount > 0
    }
    
    // MARK: - Dependencies
    private let profile: ProfileViewModel
    private let placeListService: PlaceListService
    private let collaborationService: CollaborationService
    private let userSession: UserSession
    
    // MARK: - Internal State
    private var placeCoordinates: CLLocationCoordinate2D?
    private var currentPage: Int = 1
    private let pageSize: Int = 10  // Load 10 lists at a time
    private var hasLoadedOnce: Bool = false
    private var currentPlace: DetailPlace?
    private var sharedLists: [LightweightPlaceList] = [] // Cached shared lists (don't paginate)
    
    // MARK: - Init
    init(profile: ProfileViewModel,
         placeListService: PlaceListService = PlaceListService.shared,
         collaborationService: CollaborationService = .shared,
         userSession: UserSession) {
        self.profile = profile
        self.placeListService = placeListService
        self.collaborationService = collaborationService
        self.userSession = userSession
    }
    
    deinit {
    }
    
    // MARK: - Public API
    
    func loadInitialLists(for place: DetailPlace) async {
        guard let userId = userSession.currentUserId,
              let coord = place.coordinate else { return }
        
        // Guard: Don't reload if we already have lists loaded
        // This prevents .task from wiping out paginated lists when view re-renders
        if hasLoadedOnce && !lists.isEmpty {
            return
        }
        
        // Reset state for new place
        currentPlace = place
        placeCoordinates = coord
        currentPage = 1
        hasMore = true
        isLoadingInitial = true
        placeMembership.removeAll()
        sharedLists = []
        
        // Fetch owned lists, shared lists, AND collaborative owned lists in parallel
        // This ensures ALL collaborative lists are available for the "Shared" filter
        async let ownedListsTask = fetchOwnedLists(userId: userId, coord: coord)
        async let sharedListsTask = fetchSharedLists(userId: userId)
    async let collaborativeOwnedTask = fetchCollaborativeOwnedLists(userId: userId)
    
    let (ownedLists, fetchedSharedLists, collaborativeOwnedLists) = await (ownedListsTask, sharedListsTask, collaborativeOwnedTask)
    
    // Cache shared lists for later (they don't paginate)
    sharedLists = fetchedSharedLists
    
    // Merge with proper deduplication to prevent duplicate IDs in ForEach
    // Priority: owned lists > collaborative owned > shared with me
    let uniqueLists = deduplicateLists(
        ownedLists: ownedLists,
        collaborativeOwnedLists: collaborativeOwnedLists,
        sharedLists: fetchedSharedLists
    )
    lists = uniqueLists
    hasMore = ownedLists.count >= pageSize
    hasLoadedOnce = true
        
        print("📋 [PlaceListSelectionVM] Loaded \(uniqueLists.count) unique lists (from \(ownedLists.count) owned + \(collaborativeOwnedLists.count) collab + \(fetchedSharedLists.count) shared)")
        
        // Load place membership data for all lists (so we can show checkmarks)
        if !uniqueLists.isEmpty {
            await loadPlaceMembershipForLists(uniqueLists, placeId: place.id.uuidString)
        }
        
        isLoadingInitial = false
    }
    
    // MARK: - Private Fetch Methods
    
    /// Fetches user's owned lists sorted by proximity to the place
    private func fetchOwnedLists(userId: String, coord: CLLocationCoordinate2D) async -> [LightweightPlaceList] {
        do {
            return try await placeListService.fetchListsByProximity(
                userId: userId,
                latitude: coord.latitude,
                longitude: coord.longitude,
                page: 1,
                pageSize: pageSize
            )
        } catch {
            print("❌ [PlaceListSelectionVM] Failed to fetch owned lists: \(error)")
            return []
        }
    }
    
    /// Fetches lists shared with the user (where user is a collaborator)
    private func fetchSharedLists(userId: String) async -> [LightweightPlaceList] {
        do {
            let sharedListInfos = try await collaborationService.fetchSharedLists(userId: userId)
            return sharedListInfos.map { $0.toLightweightPlaceList() }
        } catch {
            print("❌ [PlaceListSelectionVM] Failed to fetch shared lists: \(error)")
            return []
        }
    }
    
    /// Fetches user's owned lists that have collaborators
    /// This ensures collaborative owned lists appear in "Shared" filter even if not in first page
    private func fetchCollaborativeOwnedLists(userId: String) async -> [LightweightPlaceList] {
        do {
            let collaborativeOwnedInfos = try await collaborationService.fetchCollaborativeOwnedLists(userId: userId)
            return collaborativeOwnedInfos.map { $0.toLightweightPlaceList() }
        } catch {
            print("❌ [PlaceListSelectionVM] Failed to fetch collaborative owned lists: \(error)")
            return []
        }
    }
    
    func loadMoreListsIfNeeded(currentIndex: Int) async {
        // Guard: Already loading or no more to load
        guard !isLoadingMore,
              hasMore,
              let coord = placeCoordinates,
              let userId = userSession.currentUserId else {
            return
        }
        
        // Calculate position in owned lists only (shared lists are at the end and don't paginate)
        let ownedListCount = lists.count - sharedLists.count
        
        // Load when we're within 3 items of the end of OWNED lists
        guard currentIndex >= ownedListCount - 3 else {
            return
        }
        
        isLoadingMore = true
        let nextPage = currentPage + 1
        
        do {
            let moreLists = try await placeListService.fetchListsByProximity(
                userId: userId,
                latitude: coord.latitude,
                longitude: coord.longitude,
                page: nextPage,
                pageSize: pageSize
            )
            
            if !moreLists.isEmpty {
                // Deduplicate: filter out any lists already in our collection
                let existingIds = Set(lists.map { $0.list_id })
                let newUniqueLists = moreLists.filter { !existingIds.contains($0.list_id) }
                
                if !newUniqueLists.isEmpty {
                    // Insert new owned lists BEFORE shared lists
                    let insertIndex = lists.count - sharedLists.count
                    lists.insert(contentsOf: newUniqueLists, at: insertIndex)
                    
                    // Load place membership data in BACKGROUND (non-blocking)
                    // Follows Single Responsibility: Pagination ≠ Data Enrichment
                    if let placeId = currentPlace?.id.uuidString {
                        Task {
                            await loadPlaceMembershipForLists(newUniqueLists, placeId: placeId)
                        }
                    }
                }
                
                currentPage = nextPage
                hasMore = moreLists.count >= pageSize
            } else {
                hasMore = false
            }
        } catch {
            // Don't set hasMore to false on error - allow retry
        }
        
        // Release lock immediately so next page can load
        isLoadingMore = false
    }
    
    // MARK: - Private Helpers
    
    /// Deduplicates lists from multiple sources, preserving priority order
    /// Single Responsibility: Ensure unique list IDs to prevent ForEach rendering issues
    /// - Parameters:
    ///   - ownedLists: User's owned lists (highest priority)
    ///   - collaborativeOwnedLists: Owned lists with collaborators
    ///   - sharedLists: Lists shared with the user
    /// - Returns: Array of unique lists with no duplicate IDs
    private func deduplicateLists(
        ownedLists: [LightweightPlaceList],
        collaborativeOwnedLists: [LightweightPlaceList],
        sharedLists: [LightweightPlaceList]
    ) -> [LightweightPlaceList] {
        var seenIds = Set<String>()
        var uniqueLists: [LightweightPlaceList] = []
        
        // Add owned lists first (highest priority - maintains proximity sorting)
        for list in ownedLists {
            if seenIds.insert(list.list_id).inserted {
                uniqueLists.append(list)
            }
        }
        
        // Add collaborative owned lists not already in owned lists
        for list in collaborativeOwnedLists {
            if seenIds.insert(list.list_id).inserted {
                uniqueLists.append(list)
            }
        }
        
        // Add shared lists not already seen
        for list in sharedLists {
            if seenIds.insert(list.list_id).inserted {
                uniqueLists.append(list)
            }
        }
        
        return uniqueLists
    }
    
    /// Load place membership data for lists using direct database checks
    /// This checks if the specific place is in each list without loading all places
    private func loadPlaceMembershipForLists(_ listsToLoad: [LightweightPlaceList], placeId: String) async {
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
    }
    
    func isPlace(_ place: DetailPlace, in list: LightweightPlaceList) -> Bool {
        return placeMembership[list.list_id] ?? false
    }
    
    func toggle(place: DetailPlace, in list: LightweightPlaceList) {
        // CRITICAL FIX: Look up current state from our array (not the stale captured parameter)
        // Since LightweightPlaceList is a struct (value type), the parameter may be a stale snapshot
        // from when the closure was created. Always read from the source of truth: lists array.
        guard let currentList = lists.first(where: { $0.list_id == list.list_id }) else { return }
        
        let wasInList = isPlace(place, in: currentList)
        
        if wasInList {
            // Calculate new count from CURRENT state (not stale parameter)
            let newCount = max(0, currentList.place_count - 1)
            updateLocalListCount(listId: currentList.list_id, delta: -1)
            profile.removePlaceFromLightweightList(listId: currentList.list_id, place: place, updatedCount: newCount)
            placeMembership[currentList.list_id] = false
        } else {
            // Calculate new count from CURRENT state (not stale parameter)
            let newCount = currentList.place_count + 1
            updateLocalListCount(listId: currentList.list_id, delta: +1)
            profile.addPlaceToLightweightList(listId: currentList.list_id, place: place, updatedCount: newCount)
            placeMembership[currentList.list_id] = true
        }
        
        // ✅ STAFF ENGINEER: Clear recently created flag on user interaction
        // This is event-driven, not time-driven. Once user interacts with any list,
        // they've acknowledged the new list and we can clear the highlight state.
        profile.clearRecentlyCreatedList()
    }
    
    /// Update the place count for a list in our local state
    /// Follows SRP: PlaceListSelectionViewModel owns its list state
    private func updateLocalListCount(listId: String, delta: Int) {
        guard let index = lists.firstIndex(where: { $0.list_id == listId }) else { return }
        
        let oldList = lists[index]
        let newCount = max(0, oldList.place_count + delta)
        
        // Create updated list with new count (struct is immutable)
        // Preserve all collaboration fields
        let updatedList = LightweightPlaceList(
            list_id: oldList.list_id,
            name: oldList.name,
            is_public: oldList.is_public,
            image: oldList.image,
            created_at: oldList.created_at,
            updated_at: oldList.updated_at,
            distance_meters: oldList.distance_meters,
            place_count: newCount,
            city: oldList.city,
            collaborator_count: oldList.collaborator_count,
            is_shared: oldList.is_shared,
            owner_name: oldList.owner_name,
            owner_photo_url: oldList.owner_photo_url,
            user_role: oldList.user_role,
            collaborator_photos: oldList.collaborator_photos
        )
        
        lists[index] = updatedList
    }
    
    /// Adds a new list by delegating to ProfileViewModel (Single Source of Truth)
    /// and updates local selection state
    func addNewListToSelection(named name: String, city: String, emoji: String, image: String) async -> Result<Void, Error> {
        // Delegate to ProfileViewModel - it owns list creation logic
        let result = await profile.addNewPlaceList(named: name, city: city, emoji: emoji, image: image)
        
        switch result {
        case .success(let createdList):
            // Add to our local selection state for this UI context
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
            
            // Update our own paginated view (independent from ProfileViewModel's state)
            lists.insert(lightweightList, at: 0)
            
            return .success(())
            
        case .failure(let error):
            return .failure(error)
        }
    }
}

