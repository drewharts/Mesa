//
//  ExploreListDetailView.swift
//  loc
//
//  A list pushed inside the Explore sheet: its places as tiles with the map showing the list's pins.
//  Reuses the shared list places grid; tapping a place pushes its page onto the same stack.
//

import SwiftUI

/// Pushed from Explore: the list's place tiles; its header (back, title, share, creator chip) lives in the sheet's strip.
struct ExploreListDetailView: View {
    @StateObject private var viewModel: ExploreListDetailViewModel
    let onOpenPlace: (String) -> Void
    let onOpenProfile: (ProfileData) -> Void
    let onHeader: (TabSheetHeader) -> Void
    let onBack: () -> Void

    @EnvironmentObject private var userSession: UserSession
        @State private var hasAppeared = false

    /// Creates the screen for one list; `onOpenPlace` and `onOpenProfile` push a place page or the creator's profile,
    /// `onHeader` publishes the list's header (title, creator, count, share) to the sheet's strip and `onBack` pops it.
    init(
        list: ExploreList,
        onOpenPlace: @escaping (String) -> Void,
        onOpenProfile: @escaping (ProfileData) -> Void,
        onHeader: @escaping (TabSheetHeader) -> Void,
        onBack: @escaping () -> Void
    ) {
        self._viewModel = StateObject(wrappedValue: ExploreListDetailViewModel(list: list))
        self.onOpenPlace = onOpenPlace
        self.onOpenProfile = onOpenProfile
        self.onHeader = onHeader
        self.onBack = onBack
    }

    var body: some View {
        VStack(spacing: 0) {
            ListPlacesScrollView(
                places: viewModel.places,
                isLoadingInitial: viewModel.popup.isLoadingPlaces,
                isLoadingMore: false,
                showAddedBy: viewModel.popup.currentList.isCollaborative,
                focusedPlaceId: viewModel.sheet.focusedPlaceId,
                scrollRequest: viewModel.sheet.scrollRequest,
                locationText: { viewModel.locationText(for: $0) },
                onRowAppear: { viewModel.rowAppeared($0) },
                onLoadMore: {},
                onSelect: { place in viewModel.select(place, open: onOpenPlace) },
                onOpenDetail: { place in viewModel.select(place, open: onOpenPlace) },
                onRemove: nil,
                showsTypeFilter: true,
                listId: viewModel.list.id,
                hasReservablePlaces: viewModel.hasReservablePlaces == true
            )
        }
        .task { await viewModel.load() }
        .onAppear {
            publishHeader()
            if hasAppeared { viewModel.reframePins() }
            hasAppeared = true
        }
        .onChange(of: viewModel.countLabel) { _, _ in publishHeader() }
    }

    /// Sends the list's current header to the sheet's strip.
    private func publishHeader() {
        onHeader(viewModel.header(
            currentUserId: userSession.currentUserId,
            onBack: onBack,
            onOpenProfile: onOpenProfile
        ))
    }
}
