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
import Combine

/// Typed confirmation for list save/remove toast display.
struct ListConfirmation: Equatable {
    enum ActionType {
        case added
        case removed
    }

    let message: String
    let type: ActionType
}

@MainActor
class PlaceListSelectionViewModel: ObservableObject {
    // MARK: - Published State (Own Pagination)
    @Published var lists: [LightweightPlaceList] = []
    @Published var isLoadingInitial: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var hasMore: Bool = true
    @Published var placeMembership: [String: Bool] = [:] // listId -> isPlaceInList
    @Published var isFavorited: Bool = false
    
    // MARK: - Confirmation Toast State
    @Published var confirmation: ListConfirmation? = nil

    // MARK: - Filter State
    @Published var showOnlyShared: Bool = false
    @Published var searchText: String = ""
    
    // MARK: - Search State
    @Published var filteredLists: [LightweightPlaceList] = []

    /// When non-empty, tapping a list adds ALL of these places (bulk "Add all to a list").
    var bulkPlaces: [DetailPlace] = []
    @Published var isSearching: Bool = false
    
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
    private var searchCancellable: AnyCancellable?
    private var filterCancellable: AnyCancellable?
    private var confirmationDismissTask: Task<Void, Never>?
    
    // MARK: - Init
    init(profile: ProfileViewModel,
         placeListService: PlaceListService = PlaceListService.shared,
         collaborationService: CollaborationService = .shared,
         userSession: UserSession) {
        self.profile = profile
        self.placeListService = placeListService
        self.collaborationService = collaborationService
        self.userSession = userSession
        
        // Set up search observer with debouncing to avoid excessive server calls
        searchCancellable = $searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.performSearch()
                }
            }
        
        // Set up filter observer to re-apply filters when shared toggle changes
        filterCancellable = $showOnlyShared
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.performSearch()
                }
            }
    }
    
    deinit {
        searchCancellable?.cancel()
        filterCancellable?.cancel()
        confirmationDismissTask?.cancel()
    }
    
    // MARK: - Public API
    
    // MARK: - Cross-instance cache & last-used list

    /// Lists from the most recent load, keyed by user id. Lets the sheet render
    /// instantly on every open while a fresh fetch runs in the background.
    private static var cachedLists: [String: [LightweightPlaceList]] = [:]
    private static let lastUsedListKey = "PlaceListSelection.lastUsedListId"

    static var lastUsedListId: String? {
        get { UserDefaults.standard.string(forKey: lastUsedListKey) }
        set { UserDefaults.standard.set(newValue, forKey: lastUsedListKey) }
    }

    /// Coordinate to sort by: centroid of bulk places when adding all, else the single place.
    private func targetCoordinate(for place: DetailPlace) -> CLLocationCoordinate2D? {
        let coords = (bulkPlaces.isEmpty ? [place] : bulkPlaces).compactMap { $0.coordinate }
        guard !coords.isEmpty else { return place.coordinate }
        let lat = coords.map { $0.latitude }.reduce(0, +) / Double(coords.count)
        let lng = coords.map { $0.longitude }.reduce(0, +) / Double(coords.count)
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    /// Distance (meters) from the target to a list's places, using the server's
    /// proximity distance when the list was fetched for this target.
    private func distance(of list: LightweightPlaceList) -> Double? {
        guard let target = sortTarget else { return nil }
        if let avg = list.averageLocation {
            return CLLocation(latitude: avg.latitude, longitude: avg.longitude)
                .distance(from: CLLocation(latitude: target.latitude, longitude: target.longitude))
        }
        return list.distance_meters
    }

    /// Coordinate lists are sorted against (nil when the place(s) have no location).
    private var sortTarget: CLLocationCoordinate2D?

    /// Last-used list first, then by proximity, lists without located places last.
    private func sortForDisplay(_ source: [LightweightPlaceList]) -> [LightweightPlaceList] {
        let lastUsed = Self.lastUsedListId
        let indexed = Array(source.enumerated())
        return indexed.sorted { a, b in
            let aLast = a.element.list_id == lastUsed
            let bLast = b.element.list_id == lastUsed
            if aLast != bLast { return aLast }
            let da = distance(of: a.element)
            let db = distance(of: b.element)
            switch (da, db) {
            case let (x?, y?):
                if x != y { return x < y }
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                break
            }
            return a.offset < b.offset
        }.map { $0.element }
    }

    // MARK: - Public API
    
    func loadInitialLists(for place: DetailPlace) async {
        guard let userId = userSession.currentUserId else { return }
        let target = targetCoordinate(for: place)
        sortTarget = target
        // Without coordinates we still load lists; distances are just ignored.
        let coord = target ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)
        
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
        placeMembership.removeAll()
        sharedLists = []
        isFavorited = profile.favoritesViewModel.isPlaceFavorite(placeId: place.id.uuidString)

        // Show cached lists immediately (stale distances are fine for a first paint);
        // only show the spinner when we have nothing at all.
        if let cached = Self.cachedLists[userId], !cached.isEmpty {
            lists = sortForDisplay(cached)
            filteredLists = applyLocalFilters(to: lists)
            isLoadingInitial = false
        } else {
            isLoadingInitial = true
        }
        
        // Fetch owned lists, shared lists, AND collaborative owned lists in parallel
        async let ownedListsTask = fetchOwnedLists(userId: userId, coord: coord)
        async let sharedListsTask = fetchSharedLists(userId: userId)
        async let collaborativeOwnedTask = fetchCollaborativeOwnedLists(userId: userId)
    
        let (ownedLists, fetchedSharedLists, collaborativeOwnedLists) = await (ownedListsTask, sharedListsTask, collaborativeOwnedTask)
    
        // Cache shared lists for later (they don't paginate)
        sharedLists = fetchedSharedLists
    
        var uniqueLists = deduplicateLists(
            ownedLists: ownedLists,
            collaborativeOwnedLists: collaborativeOwnedLists,
            sharedLists: fetchedSharedLists
        )
        // Keep the last-used list visible even if it's beyond the first proximity page.
        if let lastUsed = Self.lastUsedListId,
           !uniqueLists.contains(where: { $0.list_id == lastUsed }),
           let cachedLast = Self.cachedLists[userId]?.first(where: { $0.list_id == lastUsed }) {
            uniqueLists.append(cachedLast)
        }
        uniqueLists = sortForDisplay(uniqueLists)
        // Count only fetched owned lists toward pagination bookkeeping.
        lists = uniqueLists
        hasMore = ownedLists.count >= pageSize
        hasLoadedOnce = true
        if !uniqueLists.isEmpty {
            Self.cachedLists[userId] = uniqueLists
        }

        filteredLists = applyLocalFilters(to: uniqueLists)
        isLoadingInitial = false

        // Membership checks (one small query per list, in parallel) run after the lists
        // are visible so they never block the first render.
        if !uniqueLists.isEmpty {
            await loadPlaceMembershipForLists(uniqueLists, placeId: place.id.uuidString)
            if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                filteredLists = applyLocalFilters(to: lists)
            }
        }
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
    
    // MARK: - Search Methods
    
    /// Performs server-side search when search text is not empty
    /// Searches ALL user lists in database regardless of pagination
    private func performSearch() async {
        guard let userId = userSession.currentUserId else { return }
        
        // If search is empty, use local filtering on loaded lists
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            filteredLists = applyLocalFilters(to: lists)
            return
        }
        
        // Perform server-side search
        isSearching = true
        
        do {
            let searchResults = try await placeListService.searchListsByName(
                userId: userId,
                searchTerm: searchText
            )

            // Load place membership BEFORE updating filteredLists
            // This prevents race condition where UI renders before membership data is ready
            if let placeId = currentPlace?.id.uuidString, !searchResults.isEmpty {
                await loadPlaceMembershipForLists(searchResults, placeId: placeId)
            }

            // Now apply local filters and update UI with membership data ready
            filteredLists = applyLocalFilters(to: searchResults)
        } catch {
            // Fallback to local filtering on error
            filteredLists = applyLocalFilters(to: lists)
        }
        
        isSearching = false
    }
    
    /// Applies local filters and sorts lists that already contain the place to the top.
    private func applyLocalFilters(to sourceLists: [LightweightPlaceList]) -> [LightweightPlaceList] {
        var result = sourceLists

        // Apply shared filter if enabled
        if showOnlyShared {
            result = result.filter { $0.isCollaborative }
        }

        // Sort lists that already contain the place to the top
        // Swift sort is stable — preserves proximity order within each group
        // (Skipped in bulk mode, where membership only reflects the first place.)
        // Last-used list stays pinned on top.
        if bulkPlaces.isEmpty {
            let lastUsed = Self.lastUsedListId
            let pinned = result.filter { $0.list_id == lastUsed }
            let rest = result.filter { $0.list_id != lastUsed }
            result = pinned + rest.filter { placeMembership[$0.list_id] == true }
                + rest.filter { placeMembership[$0.list_id] != true }
        }

        return result
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
                    
                    // Update filtered lists if not actively searching
                    if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                        filteredLists = applyLocalFilters(to: lists)
                    }
                    
                    // Load place membership data in BACKGROUND (non-blocking)
                    // Follows Single Responsibility: Pagination ≠ Data Enrichment
                    if let placeId = currentPlace?.id.uuidString {
                        Task {
                            await self.loadPlaceMembershipForLists(newUniqueLists, placeId: placeId)

                            // Re-apply filters after membership loads so new pages sort correctly
                            if self.searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                                self.filteredLists = self.applyLocalFilters(to: self.lists)
                            }
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
        if !bulkPlaces.isEmpty {
            addAll(bulkPlaces, to: list)
            return
        }
        // Prefer the freshest data from our paginated lists array, but fall back to the
        // passed-in list for search results that exist beyond the loaded page.
        let currentList = lists.first(where: { $0.list_id == list.list_id }) ?? list

        let wasInList = isPlace(place, in: currentList)
        
        if wasInList {
            // Calculate new count from CURRENT state (not stale parameter)
            let newCount = max(0, currentList.place_count - 1)
            updateLocalListCount(listId: currentList.list_id, delta: -1)
            profile.listsViewModel.removePlaceFromLightweightList(listId: currentList.list_id, place: place, updatedCount: newCount)
            placeMembership[currentList.list_id] = false
            showConfirmation("Removed from \(currentList.name)", type: .removed)
        } else {
            // Calculate new count from CURRENT state (not stale parameter)
            let newCount = currentList.place_count + 1
            updateLocalListCount(listId: currentList.list_id, delta: +1)
            profile.listsViewModel.addPlaceToLightweightList(listId: currentList.list_id, place: place, updatedCount: newCount)
            placeMembership[currentList.list_id] = true
            Self.lastUsedListId = currentList.list_id
            showConfirmation("Saved to \(currentList.name)", type: .added)
        }
        
        // ✅ STAFF ENGINEER: Clear recently created flag on user interaction
        // This is event-driven, not time-driven. Once user interacts with any list,
        // they've acknowledged the new list and we can clear the highlight state.
        profile.listsViewModel.clearRecentlyCreatedList()
    }

    /// Adds every place to the list, skipping ones already in it (checked against the DB).
    func addAll(_ places: [DetailPlace], to list: LightweightPlaceList) {
        let currentList = lists.first(where: { $0.list_id == list.list_id }) ?? list
        Self.lastUsedListId = currentList.list_id
        Task { @MainActor in
            var added = 0
            var skipped = 0
            for place in places {
                let exists = (try? await PlaceListService.shared.isPlaceInList(listId: currentList.list_id, placeId: place.id.uuidString)) ?? false
                if exists { skipped += 1; continue }
                profile.listsViewModel.addPlaceToLightweightList(listId: currentList.list_id, place: place)
                added += 1
            }
            updateLocalListCount(listId: currentList.list_id, delta: added)
            placeMembership[currentList.list_id] = true
            var message = "Added \(added) place\(added == 1 ? "" : "s") to \(currentList.name)"
            if skipped > 0 { message += " (\(skipped) already there)" }
            showConfirmation(message, type: .added)
            profile.listsViewModel.clearRecentlyCreatedList()
        }
    }

    /// Toggles the favorite status for a place via ProfileViewModel.
    func toggleFavorite(place: DetailPlace) {
        if isFavorited {
            profile.favoritesViewModel.removeFavoritePlace(place: place)
            showConfirmation("Removed from Favorites", type: .removed)
        } else {
            profile.favoritesViewModel.addFavoritePlace(place: place)
            showConfirmation("Added to Favorites", type: .added)
        }
        isFavorited.toggle()
    }
    
    /// Shows a confirmation toast and auto-clears it after 1.5 seconds.
    private func showConfirmation(_ message: String, type: ListConfirmation.ActionType) {
        confirmationDismissTask?.cancel()
        confirmation = ListConfirmation(message: message, type: type)
        confirmationDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if !Task.isCancelled {
                self?.confirmation = nil
            }
        }
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
            description: oldList.description,
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
        let result = await profile.listsViewModel.addNewPlaceList(named: name, city: city, emoji: emoji, image: image)
        
        switch result {
        case .success(let createdList):
            // Add to our local selection state for this UI context
            let lightweightList = LightweightPlaceList(
                list_id: createdList.id.uuidString,
                name: createdList.name,
                is_public: true,
                image: createdList.image,
                created_at: ISO8601DateFormatter().string(from: Date()),
                updated_at: ISO8601DateFormatter().string(from: Date()),
                distance_meters: nil,
                place_count: 0,
                city: nil
            )
            
            // Update our own paginated view (independent from ProfileViewModel's state)
            lists.insert(lightweightList, at: 0)
            
            // Update filtered lists to include the new list
            if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                filteredLists = applyLocalFilters(to: lists)
            } else {
                // If actively searching, re-run search to include new list if it matches
                Task {
                    await performSearch()
                }
            }
            
            return .success(())
            
        case .failure(let error):
            return .failure(error)
        }
    }
}

