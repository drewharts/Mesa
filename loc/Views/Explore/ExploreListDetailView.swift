//
//  ExploreListDetailView.swift
//  loc
//
//  A list pushed inside the Explore sheet: its places as tiles with the map showing the list's pins.
//  Reuses the shared list places grid; tapping a place pushes its page onto the same stack.
//

import SwiftUI

/// Pushed from Explore: compact header (back, title, share, creator chip) above the list's place tiles.
struct ExploreListDetailView: View {
    @StateObject private var viewModel: ExploreListDetailViewModel
    let onOpenPlace: (String) -> Void
    let onOpenProfile: (ProfileData) -> Void

    @EnvironmentObject private var userSession: UserSession
    @Environment(\.dismiss) private var dismiss
    @State private var hasAppeared = false

    /// Creates the screen for one list; `onOpenPlace` and `onOpenProfile` push a place page or the creator's profile.
    init(list: ExploreList, onOpenPlace: @escaping (String) -> Void, onOpenProfile: @escaping (ProfileData) -> Void) {
        self._viewModel = StateObject(wrappedValue: ExploreListDetailViewModel(list: list))
        self.onOpenPlace = onOpenPlace
        self.onOpenProfile = onOpenProfile
    }

    var body: some View {
        VStack(spacing: 0) {
            ExploreListHeaderView(
                title: viewModel.list.name,
                countLabel: viewModel.countLabel,
                creatorName: viewModel.list.ownerName,
                creatorPhotoURL: viewModel.list.ownerPhotoURL,
                isOwnList: viewModel.isOwnList(currentUserId: userSession.currentUserId),
                onBack: { dismiss() },
                onShare: { viewModel.shareList() },
                onCreatorTap: creatorTap
            )
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
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.load() }
        .onAppear {
            if hasAppeared { viewModel.reframePins() }
            hasAppeared = true
        }
    }

    /// Opens the creator's profile, or nil when the creator is unknown.
    private var creatorTap: (() -> Void)? {
        guard let profile = viewModel.ownerProfile else { return nil }
        return { onOpenProfile(profile) }
    }
}
