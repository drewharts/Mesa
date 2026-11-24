//
//  ExploreListDetailView.swift
//  loc
//
//  A list pushed inside the Explore sheet: its places as tiles with the map showing the list's pins.
//  Reuses the shared list places grid; tapping a place pushes its page onto the same stack.
//

import SwiftUI

/// Pushed from Explore: header (count and owner) above the list's place tiles.
struct ExploreListDetailView: View {
    @StateObject private var viewModel: ExploreListDetailViewModel
    let onOpenPlace: (String) -> Void

    @State private var hasAppeared = false

    /// Creates the screen for one list; `onOpenPlace` pushes a place page.
    init(list: ExploreList, onOpenPlace: @escaping (String) -> Void) {
        self._viewModel = StateObject(wrappedValue: ExploreListDetailViewModel(list: list))
        self.onOpenPlace = onOpenPlace
    }

    var body: some View {
        VStack(spacing: 0) {
            header
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
                listId: viewModel.list.id
            )
        }
        .navigationTitle(viewModel.list.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .onAppear {
            if hasAppeared { viewModel.reframePins() }
            hasAppeared = true
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: 2) {
            Text(viewModel.countLabel)
                .font(.caption)
                .contentTransition(.numericText())
                .foregroundStyle(.secondary)
            if let owner = viewModel.list.ownerName {
                Text("by \(owner)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 6)
    }
}
