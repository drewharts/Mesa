//
//  FullScreenListsView.swift
//  loc
//
//  Full-screen lists view with pinned search bar, filter chips, and pagination.
//  Presented when the user taps the search bar on the profile lists section.
//

import SwiftUI

/// Full-screen view for browsing and searching all place lists.
struct FullScreenListsView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var userSession: UserSession
    @ObservedObject var listsVM: ProfileListsViewModel

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isSearchFocused: Bool

    @State private var placeColors: [UUID: Color] = [:]
    @State private var selectedListIndex: Int? = nil
    @State private var showingNewListSheet = false
    @State private var showingGoogleMapsImport = false
    @State private var showingCreateTrip = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchHeader
                    .padding(.top, 8)

                filterAndActionsRow
                    .padding(.top, 10)

                Divider()
                    .padding(.top, 8)

                ScrollView {
                    listContent
                        .padding(.top, 12)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationBarHidden(true)
        }
        .onAppear { isSearchFocused = true }
        .sheet(isPresented: $showingNewListSheet) {
            NewListSheetView(onSave: { listName in
                let _ = await profile.listsViewModel.addNewPlaceList(named: listName, city: "", emoji: "", image: "")
            })
            .presentationDetents([.height(200)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingGoogleMapsImport) {
            GoogleMapsImportView(
                userId: profile.user?.id ?? "",
                onImportCompleted: { listId in
                    Task {
                        await listsVM.reloadListsAfterSearch()
                        if let index = listsVM.filteredPlaceLists.firstIndex(where: { $0.list_id == listId }) {
                            selectedListIndex = index
                        }
                    }
                }
            )
        }
        .fullScreenCover(isPresented: $showingCreateTrip) {
            CreateTripView { _ in showingCreateTrip = false }
                .environmentObject(userSession)
        }
        .sheet(item: Binding<ListCardIndex?>(
            get: { selectedListIndex.map { ListCardIndex(value: $0) } },
            set: { selectedListIndex = $0?.value }
        )) { item in
            LightweightListPopupView(
                lists: listsVM.filteredPlaceLists,
                initialListIndex: item.value,
                listsVM: listsVM,
                reviewsVM: profile.reviewsViewModel,
                onViewOnMap: {
                    let listId = listsVM.filteredPlaceLists[item.value].list_id
                    selectedListIndex = nil
                    profile.selectedListIdForMap = listId
                    dismiss()
                }
            )
        }
    }

    // MARK: - Search Header

    private var searchHeader: some View {
        ListsSearchBar(
            searchText: Binding(
                get: { listsVM.listSearchText },
                set: { listsVM.listSearchText = $0 }
            ),
            isFocused: $isSearchFocused,
            onCancel: {
                listsVM.listSearchText = ""
                isSearchFocused = false
                dismiss()
            }
        )
    }

    // MARK: - Filter & Actions Row

    private var filterAndActionsRow: some View {
        HStack {
            HStack(spacing: 8) {
                FilterChip(
                    label: "All",
                    isSelected: !listsVM.showOnlySharedLists,
                    onTap: { listsVM.showOnlySharedLists = false }
                )
                FilterChip(
                    label: "Shared",
                    isSelected: listsVM.showOnlySharedLists,
                    onTap: { listsVM.showOnlySharedLists = true }
                )
            }

            Spacer()

            ListActionsMenu(
                onAddList: { showingNewListSheet = true },
                onCreateTrip: { showingCreateTrip = true },
                onImportGoogleMaps: { showingGoogleMapsImport = true }
            )
        }
        .padding(.horizontal, 20)
    }

    // MARK: - List Content

    @ViewBuilder
    private var listContent: some View {
        let hasSearchText = !listsVM.listSearchText.trimmingCharacters(in: .whitespaces).isEmpty
        if listsVM.isLoadingInitialLists && !hasSearchText {
            loadingView
        } else if !listsVM.filteredPlaceLists.isEmpty {
            ListCardGrid(
                listsVM: listsVM,
                placeColors: $placeColors,
                userId: profile.user?.id ?? "",
                onListTap: { index in
                    isSearchFocused = false
                    selectedListIndex = index
                }
            )
        } else if hasSearchText {
            noResultsView
        } else {
            emptyView
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading lists...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var noResultsView: some View {
        VStack(spacing: 8) {
            Text("No matching lists")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            CreateListTileView(onTap: { showingNewListSheet = true })
        }
        .padding(.horizontal, 16)
    }
}
