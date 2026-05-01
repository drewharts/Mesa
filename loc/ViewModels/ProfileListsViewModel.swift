//
//  ProfileListsViewModel.swift
//  loc
//
//  Coordinator ViewModel for place lists management.
//  Composes child ViewModels for specific responsibilities.
//

import SwiftUI
import CoreLocation
import Combine

/// Coordinates place lists management for the current user's profile.
@MainActor
class ProfileListsViewModel: ObservableObject {
    // MARK: - Child ViewModels

    /// Core list data storage and CRUD.
    let dataViewModel: ListsDataViewModel

    /// List fetching and pagination.
    let loadingViewModel: ListsLoadingViewModel

    /// Search and filter operations.
    let searchViewModel: ListsSearchViewModel

    /// Adding/removing places from lists.
    let mutationsViewModel: ListsPlaceMutationsViewModel

    /// Distance-based list sorting.
    let distanceSortingViewModel: ListsDistanceSortingViewModel

    /// Legacy DetailPlace-based lazy loading.
    let legacyLoadingViewModel: ListsLegacyLoadingViewModel

    /// Pagination of places within individual lists.
    let placePaginationViewModel: ListsPlacePaginationViewModel

    // MARK: - Save Counts

    /// Number of saves per list (keyed by list_id).
    @Published var saveCounts: [String: Int] = [:]

    // MARK: - Combine Subscriptions

    /// Stores subscriptions to child ViewModels for change propagation.
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Callbacks for Cross-Cutting Concerns

    /// Called when placeSavers dictionary needs updating.
    var onPlaceSaversUpdate: ((String, String, Bool) -> Void)? {
        didSet { propagatePlaceSaversCallback() }
    }

    /// Called when annotation places need recalculating.
    var onAnnotationPlacesRecalculate: (() -> Void)? {
        didSet { mutationsViewModel.onAnnotationPlacesRecalculate = onAnnotationPlacesRecalculate }
    }

    /// Called when places dictionary needs updating.
    var onPlacesUpdate: ((String, DetailPlace?) -> Void)? {
        didSet { propagatePlacesUpdateCallback() }
    }

    /// Called to get place coordinate for distance calculation.
    var getPlaceCoordinate: ((String) -> CLLocationCoordinate2D?)? {
        didSet { distanceSortingViewModel.getPlaceCoordinate = getPlaceCoordinate }
    }

    /// Called to get current user's info for collaborative list attribution.
    var getUserInfo: (() -> (fullName: String?, profilePhotoURL: URL?)?)? {
        didSet { mutationsViewModel.getUserInfo = getUserInfo }
    }

    /// Called to get placeSavers for a place.
    var getPlaceSavers: ((String) -> [String]?)? {
        didSet { mutationsViewModel.getPlaceSavers = getPlaceSavers }
    }

    /// Called to fetch place image.
    var onFetchPlaceImage: ((String) -> Void)? {
        didSet { propagateFetchPlaceImageCallback() }
    }

    /// Called to set parent's loading state.
    var onSetLoading: ((Bool) -> Void)? {
        didSet { legacyLoadingViewModel.onSetLoading = onSetLoading }
    }

    /// Called to get current user ID.
    var getCurrentUserId: (() -> String?)? {
        didSet { legacyLoadingViewModel.getCurrentUserId = getCurrentUserId }
    }

    /// Called to check if a place exists in the places dictionary.
    var hasPlace: ((String) -> Bool)? {
        didSet { legacyLoadingViewModel.hasPlace = hasPlace }
    }

    // MARK: - Proxy Properties for Backward Compatibility

    /// User's place lists (legacy format).
    var userLists: [PlaceList] {
        get { dataViewModel.userLists }
        set { dataViewModel.userLists = newValue }
    }

    /// Places in each list by list ID (legacy format).
    var userListsPlaces: [String: [String]] {
        get { dataViewModel.userListsPlaces }
        set { dataViewModel.userListsPlaces = newValue }
    }

    /// Place counts per list (legacy format).
    var placeListCounts: [UUID: Int] {
        get { dataViewModel.placeListCounts }
        set { dataViewModel.placeListCounts = newValue }
    }

    /// Lightweight place lists sorted by proximity.
    var lightweightPlaceLists: [LightweightPlaceList] {
        get { dataViewModel.lightweightPlaceLists }
        set { dataViewModel.lightweightPlaceLists = newValue }
    }

    /// Places in each lightweight list.
    var lightweightPlaceListPlaces: [String: [LightweightPlace]] {
        get { dataViewModel.lightweightPlaceListPlaces }
        set { dataViewModel.lightweightPlaceListPlaces = newValue }
    }

    /// Place counts for lightweight lists.
    var lightweightPlaceListCounts: [String: Int] {
        get { dataViewModel.lightweightPlaceListCounts }
        set { dataViewModel.lightweightPlaceListCounts = newValue }
    }

    /// Loading initial lists.
    var isLoadingInitialLists: Bool {
        get { loadingViewModel.isLoadingInitialLists }
        set { loadingViewModel.isLoadingInitialLists = newValue }
    }

    /// Loading more lists (pagination).
    var isLoadingMorePlaceLists: Bool {
        get { loadingViewModel.isLoadingMorePlaceLists }
        set { loadingViewModel.isLoadingMorePlaceLists = newValue }
    }

    /// Has more lists to load.
    var hasMorePlaceLists: Bool {
        get { dataViewModel.hasMorePlaceLists }
        set { dataViewModel.hasMorePlaceLists = newValue }
    }

    /// Loaded list IDs (for lazy loading).
    var loadedListIds: Set<UUID> {
        get { legacyLoadingViewModel.loadedListIds }
        set { legacyLoadingViewModel.loadedListIds = newValue }
    }

    /// Currently loading list IDs.
    var loadingListIds: Set<UUID> {
        get { legacyLoadingViewModel.loadingListIds }
        set { legacyLoadingViewModel.loadingListIds = newValue }
    }

    /// Show only shared/collaborative lists.
    var showOnlySharedLists: Bool {
        get { searchViewModel.showOnlySharedLists }
        set { searchViewModel.showOnlySharedLists = newValue }
    }

    /// Searching lists state.
    var isSearchingLists: Bool {
        get { searchViewModel.isSearchingLists }
        set { searchViewModel.isSearchingLists = newValue }
    }

    /// List search text.
    var listSearchText: String {
        get { searchViewModel.listSearchText }
        set { searchViewModel.listSearchText = newValue }
    }

    /// Pagination state for places within each list.
    var listPlacePagination: [String: ListPlacePagination] {
        get { placePaginationViewModel.listPlacePagination }
        set { placePaginationViewModel.listPlacePagination = newValue }
    }

    /// Recently created list ID (for highlighting).
    var recentlyCreatedListId: UUID? {
        get { dataViewModel.recentlyCreatedListId }
        set { dataViewModel.recentlyCreatedListId = newValue }
    }

    /// Total list count.
    var totalListCount: Int {
        get { dataViewModel.totalListCount }
        set { dataViewModel.totalListCount = newValue }
    }

    /// Current page for list pagination.
    var placeListsCurrentPage: Int {
        get { dataViewModel.placeListsCurrentPage }
        set { dataViewModel.placeListsCurrentPage = newValue }
    }

    // MARK: - Computed Properties

    /// Returns filtered lists based on current filter state.
    var filteredPlaceLists: [LightweightPlaceList] {
        searchViewModel.filteredPlaceLists
    }

    /// Count of collaborative lists.
    var collaborativeListCount: Int {
        searchViewModel.collaborativeListCount
    }

    /// Whether there are any collaborative lists to filter.
    var hasSharedLists: Bool {
        searchViewModel.hasSharedLists
    }

    /// Whether the Shared filter button should be interactive.
    var canInteractWithSharedFilter: Bool {
        searchViewModel.canInteractWithSharedFilter
    }

    /// Whether the initial sort has been performed.
    var hasCompletedInitialSort: Bool {
        distanceSortingViewModel.hasCompletedInitialSort
    }

    // MARK: - Initialization

    /// Initializes the lists view model with required dependencies.
    init(userService: UserService, placeService: PlaceService, userSession: UserSession, locationManager: LocationManager) {
        // Create child ViewModels
        let dataVM = ListsDataViewModel(userSession: userSession, locationManager: locationManager)
        let loadingVM = ListsLoadingViewModel(userService: userService, userSession: userSession, locationManager: locationManager, dataViewModel: dataVM)
        let searchVM = ListsSearchViewModel(userService: userService, userSession: userSession, locationManager: locationManager, dataViewModel: dataVM, loadingViewModel: loadingVM)
        let mutationsVM = ListsPlaceMutationsViewModel(placeService: placeService, userSession: userSession, dataViewModel: dataVM)
        let distanceSortingVM = ListsDistanceSortingViewModel(userSession: userSession, locationManager: locationManager, dataViewModel: dataVM)
        let legacyLoadingVM = ListsLegacyLoadingViewModel(placeService: placeService, dataViewModel: dataVM)
        let placePaginationVM = ListsPlacePaginationViewModel(placeService: placeService, dataViewModel: dataVM)
        // Store references
        self.dataViewModel = dataVM
        self.loadingViewModel = loadingVM
        self.searchViewModel = searchVM
        self.mutationsViewModel = mutationsVM
        self.distanceSortingViewModel = distanceSortingVM
        self.legacyLoadingViewModel = legacyLoadingVM
        self.placePaginationViewModel = placePaginationVM

        // Wire up cross-ViewModel references
        mutationsVM.setDistanceSortingViewModel(distanceSortingVM)
        mutationsVM.setPlacePaginationViewModel(placePaginationVM)
        legacyLoadingVM.setPlacePaginationViewModel(placePaginationVM)

        // Wire up data ViewModel callback
        dataVM.onSortListsByDistance = { [weak distanceSortingVM] in
            distanceSortingVM?.sortListsByDistance()
        }

        // Wire up child ViewModel change propagation
        setupChildViewModelObservers()
    }

    // MARK: - Child ViewModel Change Propagation

    /// Subscribes to child ViewModels and forwards their changes to trigger parent updates.
    private func setupChildViewModelObservers() {
        // Data changes (lists added/removed, places updated)
        dataViewModel.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        // Loading state changes (isLoadingMorePlaceLists, isLoadingInitialLists)
        loadingViewModel.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        // Search/filter state changes
        searchViewModel.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        // Mutations state changes
        mutationsViewModel.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        // Distance sorting state changes
        distanceSortingViewModel.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        // Legacy loading state changes
        legacyLoadingViewModel.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        // Place pagination state changes
        placePaginationViewModel.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

    }

    // MARK: - Callback Propagation

    /// Propagates the placeSavers callback to child ViewModels.
    private func propagatePlaceSaversCallback() {
        loadingViewModel.onPlaceSaversUpdate = onPlaceSaversUpdate
        mutationsViewModel.onPlaceSaversUpdate = onPlaceSaversUpdate
    }

    /// Propagates the places update callback to child ViewModels.
    private func propagatePlacesUpdateCallback() {
        mutationsViewModel.onPlacesUpdate = onPlacesUpdate
        legacyLoadingViewModel.onPlacesUpdate = onPlacesUpdate
        placePaginationViewModel.onPlacesUpdate = onPlacesUpdate
    }

    /// Propagates the fetch place image callback to child ViewModels.
    private func propagateFetchPlaceImageCallback() {
        legacyLoadingViewModel.onFetchPlaceImage = onFetchPlaceImage
        placePaginationViewModel.onFetchPlaceImage = onFetchPlaceImage
    }

    // MARK: - Delegated Methods - List CRUD

    /// Creates a new place list with full state management.
    func addNewPlaceList(named name: String, city: String, emoji: String, image: String) async -> Result<PlaceList, Error> {
        await dataViewModel.addNewPlaceList(named: name, city: city, emoji: emoji, image: image)
    }

    /// Renames a lightweight place list in the database and updates local state.
    func renameList(_ list: LightweightPlaceList, newName: String) async -> Result<Void, Error> {
        await dataViewModel.renameList(list, newName: newName)
    }

    /// Updates the description of a lightweight place list from raw user input.
    func updateListDescription(_ list: LightweightPlaceList, rawText: String) async -> Result<Void, Error> {
        let trimmed = rawText.trimmingCharacters(in: .whitespaces)
        let newDescription: String? = trimmed.isEmpty ? nil : trimmed
        return await dataViewModel.updateListDescription(list, newDescription: newDescription)
    }

    /// Deletes a lightweight place list from database and removes from local state.
    func deleteLightweightList(_ list: LightweightPlaceList) async -> Result<Void, Error> {
        await dataViewModel.deleteLightweightList(list)
    }

    /// Removes a place list (legacy PlaceList format).
    func removePlaceList(placeList: PlaceList) {
        dataViewModel.removePlaceList(placeList: placeList)
    }

    // MARK: - Delegated Methods - Place Count & Membership

    /// Gets place count for a list.
    func placeCount(forListId listId: UUID) -> Int {
        mutationsViewModel.placeCount(forListId: listId)
    }

    /// Checks if a place is in a specific list.
    func isPlaceInList(listId: UUID, placeId: String) -> Bool {
        mutationsViewModel.isPlaceInList(listId: listId, placeId: placeId)
    }

    /// Checks if a place is in any of the user's lists.
    func isPlaceInAnyList(placeId: String) async -> Bool {
        await mutationsViewModel.isPlaceInAnyList(placeId: placeId)
    }

    // MARK: - Delegated Methods - Add/Remove Place

    /// Add a place to a lightweight list (current format).
    func addPlaceToLightweightList(listId: String, place: DetailPlace, updatedCount: Int? = nil) {
        mutationsViewModel.addPlaceToLightweightList(listId: listId, place: place, updatedCount: updatedCount)
    }

    /// Add a place to a list (old UUID-based format).
    func addPlaceToList(listId: UUID, place: DetailPlace) {
        mutationsViewModel.addPlaceToList(listId: listId, place: place)
    }

    /// Remove a place from a lightweight list using a DetailPlace reference.
    func removePlaceFromLightweightList(listId: String, place: DetailPlace, updatedCount: Int? = nil) {
        mutationsViewModel.removePlaceFromLightweightList(listId: listId, place: place, updatedCount: updatedCount)
    }

    /// Remove a place from a lightweight list by place ID.
    func removePlaceFromLightweightList(listId: String, placeId: String) {
        mutationsViewModel.removePlaceFromLightweightList(listId: listId, placeId: placeId)
    }

    /// Remove a place from a list (old UUID-based format).
    func removePlaceFromList(listId: UUID, place: DetailPlace) {
        mutationsViewModel.removePlaceFromList(listId: listId, place: place)
    }

    // MARK: - Delegated Methods - Pagination

    /// Reset pagination for a list.
    func resetListPagination(listId: UUID) {
        placePaginationViewModel.resetListPagination(listId: listId)
    }

    /// Initialize pagination if needed.
    func initializeListPaginationIfNeeded(listId: UUID) {
        placePaginationViewModel.initializeListPaginationIfNeeded(listId: listId)
    }

    /// Load the next page of places for a specific list.
    func loadNextPageForList(listId: UUID) {
        placePaginationViewModel.loadNextPageForList(listId: listId)
    }

    /// Get the displayed place IDs for a list.
    func getDisplayedPlaceIds(for listId: UUID) -> [String] {
        placePaginationViewModel.getDisplayedPlaceIds(for: listId)
    }

    /// Check if a list has more places to load.
    func hasMorePlaces(for listId: UUID) -> Bool {
        placePaginationViewModel.hasMorePlaces(for: listId)
    }

    /// Check if a list is currently loading more places.
    func isLoadingMorePlaces(for listId: UUID) -> Bool {
        placePaginationViewModel.isLoadingMorePlaces(for: listId)
    }

    /// Get the total number of places in a list.
    func getTotalPlaceCount(for listId: UUID) -> Int {
        placePaginationViewModel.getTotalPlaceCount(for: listId)
    }

    // MARK: - Delegated Methods - Recently Created List

    /// Sets the recently created list ID.
    func setRecentlyCreatedList(_ listId: UUID) {
        dataViewModel.setRecentlyCreatedList(listId)
    }

    /// Clears the recently created list flag.
    func clearRecentlyCreatedList() {
        dataViewModel.clearRecentlyCreatedList()
    }

    /// Checks if a list is recently created.
    func isListRecentlyCreated(_ listId: UUID) -> Bool {
        dataViewModel.isListRecentlyCreated(listId)
    }

    // MARK: - Delegated Methods - Sorting

    /// Sorts userLists by their distance from the user's current location.
    func sortListsByDistance() {
        distanceSortingViewModel.sortListsByDistance()
    }

    /// Recalculates the average coordinates for a specific list.
    func recalculateAverageCoordinates(for listId: UUID) {
        distanceSortingViewModel.recalculateAverageCoordinates(for: listId)
    }

    // MARK: - Delegated Methods - Loading

    /// Loads the initial page of lists.
    func loadInitialLists() async {
        await loadingViewModel.loadInitialLists()
    }

    /// Loads more lists with pagination.
    func loadMoreLists() async {
        await loadingViewModel.loadMoreLists()
    }

    /// Loads lists sorted by proximity to a specific place's coordinates.
    func loadListsByPlaceCoordinates(placeLatitude: Double, placeLongitude: Double) async {
        await loadingViewModel.loadListsByPlaceCoordinates(placeLatitude: placeLatitude, placeLongitude: placeLongitude)
    }

    /// Loads places for multiple lists in parallel.
    func loadPlacesForLists(_ lists: [LightweightPlaceList]) async {
        await loadingViewModel.loadPlacesForLists(lists)
    }

    /// Loads places for a list if not cached or if the cache is partial (e.g. from an optimistic insert).
    func loadPlacesForListIfNeeded(listId: String, fallbackCount: Int) async {
        await loadingViewModel.loadPlacesForListIfNeeded(listId: listId, fallbackCount: fallbackCount)
    }

    /// Loads places for a single list.
    func loadPlacesForList(listId: String) async {
        await loadingViewModel.loadPlacesForList(listId: listId)
    }

    /// Loads more places for a list with pagination.
    func loadMorePlacesForList(listId: String, page: Int, pageSize: Int = 6) async throws -> [LightweightPlace] {
        try await loadingViewModel.loadMorePlacesForList(listId: listId, page: page, pageSize: pageSize)
    }

    /// Checks if more lists should be loaded based on scroll position.
    func shouldLoadMoreLists(currentItem: LightweightPlaceList, filteredLists: [LightweightPlaceList], isSearching: Bool) -> Bool {
        loadingViewModel.shouldLoadMoreLists(currentItem: currentItem, filteredLists: filteredLists, isSearching: isSearching)
    }

    // MARK: - Delegated Methods - Legacy Loading

    /// Ensures lists are loaded with DetailPlace data for legacy views.
    func ensureListsLoaded() {
        legacyLoadingViewModel.ensureListsLoaded()
    }

    /// Loads list data if needed for a specific list.
    func loadListDataIfNeeded(listId: UUID) {
        legacyLoadingViewModel.loadListDataIfNeeded(listId: listId)
    }

    /// Load more lists when user scrolls.
    func loadMoreListsIfNeeded() {
        legacyLoadingViewModel.loadMoreListsIfNeeded()
    }

    // MARK: - Delegated Methods - State Management

    /// Appends new place lists with deduplication.
    func appendPlaceLists(_ newLists: [LightweightPlaceList], nextPage: Int, pageSize: Int) {
        dataViewModel.appendPlaceLists(newLists, nextPage: nextPage, pageSize: pageSize)
    }

    /// Sets places for a list with deduplication.
    func setPlacesForList(listId: String, places: [LightweightPlace]) {
        dataViewModel.setPlacesForList(listId: listId, places: places)
    }

    /// Appends places for a list with deduplication.
    func appendPlacesForList(listId: String, newPlaces: [LightweightPlace]) {
        dataViewModel.appendPlacesForList(listId: listId, newPlaces: newPlaces)
    }

    // MARK: - Delegated Methods - Search

    /// Performs server-side search across all user lists.
    func performListSearch() async {
        await searchViewModel.performListSearch()
    }

    /// Reloads lists when exiting search mode.
    func reloadListsAfterSearch() async {
        await searchViewModel.reloadListsAfterSearch()
    }

    // MARK: - Save Count

    /// Fetches the save count for a list and caches the result.
    func fetchSaveCount(listId: String) async {
        guard saveCounts[listId] == nil else { return }
        let count = (try? await SavedListService.shared.getSaveCount(listId: listId)) ?? 0
        saveCounts[listId] = count
    }

    // MARK: - Reset

    /// Resets all lists data (used during logout).
    func resetAllData() {
        dataViewModel.resetAllData()
        loadingViewModel.resetLoadingStates()
        searchViewModel.resetSearchState()
        distanceSortingViewModel.resetSortingState()
        legacyLoadingViewModel.resetLegacyLoadingState()
        placePaginationViewModel.resetPaginationState()
        saveCounts = [:]
    }
}
