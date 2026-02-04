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
        print("📄 [ListPopupPaginationViewModel] loadMoreIfNeeded called for list \(listId)")

        // Ensure dependencies are set
        guard listsVM != nil else {
            print("⚠️ [ListPopupPaginationViewModel] listsVM not set, skipping load")
            return
        }

        // Initialize state if needed (don't return early)
        if paginationStates[listId] == nil {
            print("📄 [ListPopupPaginationViewModel] Initializing state for list \(listId)")
            initializeStateIfNeeded(for: listId)
        }

        guard var state = paginationStates[listId] else { return }

        guard state.hasMorePlaces, !state.isLoadingMore else {
            if state.isLoadingMore {
                print("📄 [ListPopupPaginationViewModel] Already loading, marking pending request")
                state.pendingLoadRequest = true
                paginationStates[listId] = state
            } else {
                print("📄 [ListPopupPaginationViewModel] No more places to load (hasMorePlaces=\(state.hasMorePlaces))")
            }
            return
        }

        print("📄 [ListPopupPaginationViewModel] Starting load for page \(state.currentPage + 1)")

        state.isLoadingMore = true
        state.pendingLoadRequest = false
        paginationStates[listId] = state

        let nextPage = state.currentPage + 1

        Task {
            await performLoadMore(for: listId, nextPage: nextPage)
        }
    }

    /// Calculates height for a list considering the filter state.
    func calculateHeight(for listId: String, showOnlyUnvisited: Bool) -> CGFloat {
        guard let listsVM = listsVM, let reviewsVM = reviewsVM else { return 300 }

        let allPlaces = listsVM.lightweightPlaceListPlaces[listId] ?? []
        let filteredCount = showOnlyUnvisited
            ? allPlaces.filter { !reviewsVM.hasVerifiedReviewedPlace(placeId: $0.place_id) }.count
            : allPlaces.count

        let rows = ceil(Double(filteredCount) / 2.0)
        return max(300, min(rows * 200 + 100, 2000))
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
            print("⚠️ [ListPopupPaginationViewModel] listsVM is nil in performLoadMore")
            updateState(for: listId) { state in state.isLoadingMore = false }
            return
        }

        print("📄 [ListPopupPaginationViewModel] Loading page \(nextPage) for list \(listId)")

        do {
            let morePlaces = try await listsVM.loadMorePlacesForList(
                listId: listId,
                page: nextPage,
                pageSize: 6
            )

            print("📄 [ListPopupPaginationViewModel] Loaded \(morePlaces.count) more places for list \(listId)")

            listsVM.appendPlacesForList(listId: listId, newPlaces: morePlaces)

            let totalPlaces = listsVM.lightweightPlaceListPlaces[listId]?.count ?? 0
            print("📄 [ListPopupPaginationViewModel] Total places now: \(totalPlaces)")

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
