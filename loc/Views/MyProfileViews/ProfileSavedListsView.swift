//
//  ProfileSavedListsView.swift
//  loc
//
//  DUMB Component: Displays saved lists from other users on the user's profile.
//  Single Responsibility: Render saved lists UI based on SavedListsViewModel state.
//

import SwiftUI

/// Identifiable wrapper for saved list popup presentation.
private struct SavedListIndex: Identifiable {
    let value: Int
    var id: Int { value }
}

/// Displays saved lists section on the user's own profile.
struct ProfileSavedListsView: View {
    @ObservedObject var viewModel: SavedListsViewModel
    @EnvironmentObject var profile: ProfileViewModel

    @State private var placeColors: [UUID: Color] = [:]
    @State private var selectedListIndex: SavedListIndex?

    private let listColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        if !viewModel.savedLists.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader
                savedListsGrid
            }
            .sheet(item: $selectedListIndex) { item in
                if item.value < viewModel.savedLists.count {
                    savedListPopup(index: item.value)
                }
            }
        }
    }

    // MARK: - Section Header

    private var sectionHeader: some View {
        HStack {
            Text("Saved Lists")
                .font(.headline)
                .foregroundColor(.primary)

            Text("\(viewModel.savedLists.count)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(.systemGray6))
                .clipShape(Capsule())

            Spacer()
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Saved Lists Grid

    private var savedListsGrid: some View {
        LazyVGrid(columns: listColumns, spacing: 16) {
            ForEach(Array(viewModel.savedLists.enumerated()), id: \.element.id) { index, list in
                ProfileListCard(
                    list: list,
                    places: viewModel.savedListPlaces[list.list_id] ?? [],
                    placeColors: $placeColors,
                    config: .external,
                    onTap: { selectedListIndex = SavedListIndex(value: index) }
                )
                .contextMenu {
                    Button(role: .destructive) {
                        Task {
                            _ = await viewModel.unsaveList(listId: list.list_id)
                        }
                    } label: {
                        Label("Unsave List", systemImage: "bookmark.slash")
                    }
                }
                .onAppear {
                    if index == viewModel.savedLists.count - 2 {
                        Task { await viewModel.loadMoreLists() }
                    }
                }
            }

            if viewModel.isLoadingMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Saved List Popup

    /// Presents a saved list popup showing the list's places.
    @ViewBuilder
    private func savedListPopup(index: Int) -> some View {
        let list = viewModel.savedLists[index]
        let places = viewModel.savedListPlaces[list.list_id] ?? []
        SavedListPopupView(
            list: list,
            places: places,
            placeColors: $placeColors
        )
    }
}
