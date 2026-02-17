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
