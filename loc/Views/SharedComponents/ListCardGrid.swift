//
//  ListCardGrid.swift
//  loc
//
//  DUMB Component: Renders a 2-column grid of list cards with pagination.
//  Reused by both ProfileViewListsView and FullScreenListsView.
//

import SwiftUI

/// Identifiable wrapper for Int index, used for sheet(item:) presentation.
struct ListCardIndex: Identifiable {
    let value: Int
    var id: Int { value }
}

/// 2-column grid of list cards with context menus and pagination.
struct ListCardGrid: View {
    @ObservedObject var listsVM: ProfileListsViewModel
    @Binding var placeColors: [UUID: Color]
    let userId: String
    let onListTap: (Int) -> Void

    @StateObject private var shareCardVM = ListStoryCardViewModel()
    @State private var listToDelete: LightweightPlaceList?
    @State private var showDeleteConfirmation = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(Array(listsVM.filteredPlaceLists.enumerated()), id: \.element.id) { index, list in
                LightweightProfileListSection(
                    list: list,
                    places: listsVM.lightweightPlaceListPlaces[list.list_id] ?? [],
                    allLists: listsVM.filteredPlaceLists,
                    currentIndex: index,
                    placeCount: listsVM.lightweightPlaceListCounts[list.list_id] ?? list.place_count,
                    placeColors: $placeColors,
                    onTap: { onListTap(index) }
                )
                .contextMenu {
                    Button {
                        Task {
                            await shareCardVM.quickShare(
                                list: list,
                                places: listsVM.lightweightPlaceListPlaces[list.list_id] ?? [],
                                userId: userId,
                                shareService: ServiceContainer.shared.placeShareService
                            )
                        }
                    } label: {
                        Label("Share List", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive) {
                        listToDelete = list
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete List", systemImage: "trash")
                    }
                }
                .onAppear {
                    guard listsVM.listSearchText.isEmpty, !listsVM.showOnlySharedLists else { return }
                    if listsVM.shouldLoadMoreLists(
                        currentItem: list,
                        filteredLists: listsVM.filteredPlaceLists,
                        isSearching: false
                    ) {
                        Task { await listsVM.loadMoreLists() }
                    }
                }
            }

            if listsVM.hasMorePlaceLists && !listsVM.isLoadingMorePlaceLists {
                Color.clear
                    .frame(height: 1)
                    .onAppear {
                        Task { await listsVM.loadMoreLists() }
                    }
            }

            if listsVM.isLoadingMorePlaceLists {
                HStack {
                    Spacer()
                    ProgressView().padding()
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 16)
        .alert("Delete List", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { listToDelete = nil }
            Button("Delete", role: .destructive) {
                if let list = listToDelete {
                    Task {
                        _ = await listsVM.deleteLightweightList(list)
                        listToDelete = nil
                    }
                }
            }
        } message: {
            if let list = listToDelete {
                Text("Are you sure you want to delete \"\(list.name)\"? This action cannot be undone.")
            }
        }
    }
}
