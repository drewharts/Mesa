//
//  ListPopupPaginationViewModel.swift
//  loc
//
//  Manages per-list pagination state for list popup sheets.
//

import SwiftUI
import Combine

/// Pagination state for a single list in the popup.
struct ListPaginationState {
    var currentPage: Int = 1
    var isLoadingMore: Bool = false
    var hasMorePlaces: Bool = true
    var pendingLoadRequest: Bool = false
    var cachedHeight: CGFloat = 300
    var hasLoadedReviewedIds: Bool = false
}

/// Manages per-list pagination state for LightweightListPopupView.
@MainActor
class ListPopupPaginationViewModel: ObservableObject {

    // MARK: - Published Properties

    /// Pagination state for each list by list ID.
    @Published private(set) var paginationStates: [String: ListPaginationState] = [:]

    /// Error message for display.
    @Published var errorMessage: String? = nil

    // MARK: - Dependencies

    private weak var listsVM: ProfileListsViewModel?
    private weak var reviewsVM: ProfileReviewsViewModel?

    // MARK: - Public Methods

    /// Sets dependencies after view initialization.
    func setDependencies(listsVM: ProfileListsViewModel?, reviewsVM: ProfileReviewsViewModel?) {
        self.listsVM = listsVM
        self.reviewsVM = reviewsVM
    }

    /// Returns pagination state for a list.
    func state(for listId: String) -> ListPaginationState {
        paginationStates[listId] ?? ListPaginationState()
    }

    /// Called when switching lists - loads reviewed IDs and updates state.
    func onListChanged(to listId: String) async {
        initializeStateIfNeeded(for: listId)
        await loadReviewedPlaceIds(for: listId)
    }

    /// Loads more places for a list if conditions are met.
    func loadMoreIfNeeded(for listId: String) {
        guard listsVM != nil else { return }

        if paginationStates[listId] == nil {
            initializeStateIfNeeded(for: listId)
        }

        guard var state = paginationStates[listId] else { return }

        guard state.hasMorePlaces, !state.isLoadingMore else {
            if state.isLoadingMore {
                state.pendingLoadRequest = true
                paginationStates[listId] = state
            }
            return
        }

        state.isLoadingMore = true
        state.pendingLoadRequest = false
        paginationStates[listId] = state

        let nextPage = state.currentPage + 1

        Task {
            await performLoadMore(for: listId, nextPage: nextPage)
        }
    }

    /// Largest number of places loaded when fetching a whole list.
    private static let maxFullLoadCount = 1000

    /// Places fetched per request when loading a whole list (smaller requests stay fast and reliable).
    private static let fullLoadChunkSize = 100

    /// Loads every place of a list in chunked requests so each pin on the map has a matching row and tag
    /// chips can show all their matches. Keeps optimistic local inserts; keeps what loaded if a chunk fails.
    func loadAllPlaces(for listId: String, expectedCount: Int) async {
        guard let listsVM = listsVM else { return }
        initializeStateIfNeeded(for: listId)

        let loadedCount = listsVM.lightweightPlaceListPlaces[ListPlaceCount.normalizedId(listId)]?.count
            ?? listsVM.lightweightPlaceListPlaces[listId]?.count
            ?? 0
        await waitForPageLoadToFinish(listId: listId)
        let alreadyComplete = paginationStates[listId]?.hasMorePlaces == false && loadedCount > 0
        guard !alreadyComplete, paginationStates[listId]?.isLoadingMore != true else { return }

        updateState(for: listId) { state in state.isLoadingMore = true }
        let (fetched, knownComplete) = await fetchAllPages(listId: listId, listsVM: listsVM)
        guard !fetched.isEmpty || knownComplete else {
            updateState(for: listId) { state in state.isLoadingMore = false }
            return
        }
        let fetchedIds = Set(fetched.map { $0.place_id.lowercased() })
        let localOnly = (listsVM.lightweightPlaceListPlaces[ListPlaceCount.normalizedId(listId)]
            ?? listsVM.lightweightPlaceListPlaces[listId]
            ?? []).filter { !fetchedIds.contains($0.place_id.lowercased()) }
        listsVM.setPlacesForList(listId: listId, places: fetched + localOnly)
        listsVM.dataViewModel.syncLoadedPlaceCount(
            listId: listId,
            loaded: fetched.count + localOnly.count,
            knownComplete: knownComplete
        )
        updateState(for: listId) { state in
            state.currentPage = max(1, fetched.count / 6)
            state.hasMorePlaces = !knownComplete
            state.isLoadingMore = false
        }
    }

    /// Suspends until an in-flight page load for the list finishes (bounded), so a full load requested right
    /// after a scroll-triggered page load waits for it instead of silently doing nothing.
    private func waitForPageLoadToFinish(listId: String) async {
        var waited = 0
        while paginationStates[listId]?.isLoadingMore == true, waited < Self.maxPageWaitMillis, !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 50_000_000)
            waited += 50
        }
    }

    /// Longest a full load waits for an in-flight page load before giving up.
    private static let maxPageWaitMillis = 10_000

    /// Fetches a list's places chunk by chunk; returns what loaded and whether the end of the list was reached.
    private func fetchAllPages(listId: String, listsVM: ProfileListsViewModel) async -> (places: [LightweightPlace], complete: Bool) {
        var all: [LightweightPlace] = []
        var page = 1
        while all.count < Self.maxFullLoadCount {
            do {
                let chunk = try await listsVM.loadMorePlacesForList(listId: listId, page: page, pageSize: Self.fullLoadChunkSize)
                all += chunk
                if chunk.count < Self.fullLoadChunkSize { return (all, true) }
                page += 1
            } catch {
                print("❌ [ListPopupPaginationViewModel] Error loading all places: \(error.localizedDescription)")
                return (all, false)
            }
        }
        return (all, false)
    }

    /// Resets pagination state for a specific list.
    func resetState(for listId: String) {
        paginationStates[listId] = ListPaginationState()
    }

    // MARK: - Private Methods

    /// Initializes pagination state for a list if not already present.
    private func initializeStateIfNeeded(for listId: String) {
        if paginationStates[listId] == nil {
            paginationStates[listId] = ListPaginationState()
        }
    }

    /// Loads reviewed place IDs from database for accurate filtering.
    private func loadReviewedPlaceIds(for listId: String) async {
        guard let listsVM = listsVM, let reviewsVM = reviewsVM else { return }
        let placeIds = (listsVM.lightweightPlaceListPlaces[listId] ?? []).map { $0.place_id }
        guard !placeIds.isEmpty else { return }

        await reviewsVM.loadVerifiedReviewedPlaceIds(for: placeIds)
        updateState(for: listId) { state in
            state.hasLoadedReviewedIds = true
        }
    }

    /// Performs the actual load more operation.
    private func performLoadMore(for listId: String, nextPage: Int) async {
        guard let listsVM = listsVM else {
            updateState(for: listId) { state in state.isLoadingMore = false }
            return
        }

        do {
            let morePlaces = try await listsVM.loadMorePlacesForList(
                listId: listId,
                page: nextPage,
                pageSize: 6
            )

            listsVM.appendPlacesForList(listId: listId, newPlaces: morePlaces)

            updateState(for: listId) { state in
                state.currentPage = nextPage
                state.hasMorePlaces = morePlaces.count >= 6
                state.isLoadingMore = false
            }

            // Process pending request if one was queued
            if let currentState = paginationStates[listId],
               currentState.pendingLoadRequest && currentState.hasMorePlaces {
                loadMoreIfNeeded(for: listId)
            }
        } catch {
            updateState(for: listId) { state in state.isLoadingMore = false }
            errorMessage = "Failed to load more places"
            print("❌ [ListPopupPaginationViewModel] Error loading more places: \(error.localizedDescription)")
        }
    }

    /// Updates pagination state for a list using a closure.
    private func updateState(for listId: String, update: (inout ListPaginationState) -> Void) {
        var state = paginationStates[listId] ?? ListPaginationState()
        update(&state)
        paginationStates[listId] = state
    }
}
