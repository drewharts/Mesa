//
//  ProfileViewListsView.swift
//  loc
//
//  DUMB Component: Displays user's place lists with filter and pagination
//  Single Responsibility: Render list UI based on ViewModel state
//
//  Reactively displays:
//  - Loading state (while initial fetch in progress)
//  - Filtered lists (all or shared-only based on filter)
//  - Empty states (no lists vs no shared lists)
//  - Pagination loading indicator
//
//  Created by Andrew Hartsfield II on 12/14/24.
//

import SwiftUI
import PhotosUI

/// Identifiable wrapper for Int index, used for sheet(item:) presentation.
private struct IdentifiableIndex: Identifiable {
    let value: Int
    var id: Int { value }
}

struct ProfileViewListsView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @EnvironmentObject var deepLinkManager: DeepLinkManager
    @ObservedObject var listsVM: ProfileListsViewModel
    @Environment(\.presentationMode) private var presentationMode

    @State private var showingImagePicker = false
    @State private var inputImage: [UIImage] = []
    @State private var selectedList: PlaceListViewModel?
    @State private var showingNewListSheet = false
    @State private var placeColors: [UUID: Color] = [:]
    @State private var listToDelete: LightweightPlaceList?
    @State private var showDeleteConfirmation = false
    @State private var selectedListIndex: Int? = nil
    @State private var pendingMapListId: String? = nil
    @State private var showingGoogleMapsImport = false

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            listsSearchBar
            listContent
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(images: $inputImage, selectionLimit: 1)
        }
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
                        // Open the newly created list
                        if let index = listsVM.filteredPlaceLists.firstIndex(where: { $0.list_id == listId }) {
                            selectedListIndex = index
                        }
                    }
                }
            )
        }
        .sheet(isPresented: .constant(deepLinkManager.hasPendingList()), onDismiss: {
            deepLinkManager.clearPendingList()
        }) {
            if let pendingList = deepLinkManager.pendingList {
                SwipeableListPopupView(
                    lists: pendingList.lists,
                    initialListIndex: pendingList.initialIndex,
                    placeColors: $placeColors,
                    listsVM: listsVM,
                    reviewsVM: profile.reviewsViewModel
                )
            }
        }
        .onChange(of: selectedPlaceVM.isDetailSheetPresented) {
            if selectedPlaceVM.isDetailSheetPresented == true {
                presentationMode.wrappedValue.dismiss()
            }
        }
        .alert("Delete List", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                listToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let list = listToDelete {
                    Task {
                        let result = await profile.listsViewModel.deleteLightweightList(list)
                        if case .failure = result {
                            // Could show error alert here if needed
                        }
                        listToDelete = nil
                    }
                }
            }
        } message: {
            if let list = listToDelete {
                Text("Are you sure you want to delete \"\(list.name)\"? This action cannot be undone.")
            }
        }
        .sheet(item: Binding<IdentifiableIndex?>(
            get: { selectedListIndex.map { IdentifiableIndex(value: $0) } },
            set: { selectedListIndex = $0?.value }
        ), onDismiss: handleListPopupDismiss) { item in
            LightweightListPopupView(
                lists: listsVM.filteredPlaceLists,
                initialListIndex: item.value,
                listsVM: listsVM,
                reviewsVM: profile.reviewsViewModel,
                onViewOnMap: {
                    pendingMapListId = listsVM.filteredPlaceLists[item.value].list_id
                    selectedListIndex = nil
                }
            )
        }
    }
    
    // MARK: - Lists Search Bar

    private var listsSearchBar: some View {
        ListsSearchBar(
            searchText: Binding(
                get: { listsVM.listSearchText },
                set: { listsVM.listSearchText = $0 }
            ),
            showOnlyShared: listsVM.showOnlySharedLists,
            hasSharedLists: listsVM.hasSharedLists,
            isFilterEnabled: listsVM.canInteractWithSharedFilter,
            isGroupingEnabled: listsVM.cityGroupingViewModel.isGroupingEnabled,
            onToggleFilter: {
                listsVM.showOnlySharedLists.toggle()
            },
            onToggleGrouping: {
                listsVM.cityGroupingViewModel.isGroupingEnabled.toggle()
            },
            onAddList: {
                showingNewListSheet = true
            },
            onImportGoogleMapsList: {
                showingGoogleMapsImport = true
            }
        )
    }
    
    // MARK: - List Content (State-based rendering)
    
    @ViewBuilder
    private var listContent: some View {
        if listsVM.isLoadingInitialLists {
            initialLoadingView
        } else if !listsVM.filteredPlaceLists.isEmpty {
            if listsVM.cityGroupingViewModel.shouldShowGrouped {
                groupedListView
            } else {
                flatListView
            }
        } else {
            emptyStateView
        }
    }
    
    // MARK: - Initial Loading View
    
    private var initialLoadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading lists...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - List Views

    // 2-column grid for displaying lists side by side
    private let listColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    // MARK: - Grouped List View

    private var groupedListView: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(listsVM.groupedPlaceLists) { group in
                CityGroupHeaderView(
                    city: group.city,
                    listCount: group.lists.count,
                    isCollapsed: listsVM.isCityCollapsed(group.city),
                    onTap: { listsVM.toggleCityGroup(group.city) }
                )

                if !listsVM.isCityCollapsed(group.city) {
                    LazyVGrid(columns: listColumns, spacing: 16) {
                        ForEach(Array(group.lists.enumerated()), id: \.element.id) { _, list in
                            groupedListCard(for: list)
                        }
                    }
                }
            }

            paginationTrigger
        }
        .padding(.horizontal, 16)
    }

    /// Renders a single list card within a grouped section, resolving the flat index for the popup.
    private func groupedListCard(for list: LightweightPlaceList) -> some View {
        let flatIndex = listsVM.filteredPlaceLists.firstIndex(where: { $0.list_id == list.list_id })
        return LightweightProfileListSection(
            list: list,
            places: listsVM.lightweightPlaceListPlaces[list.list_id] ?? [],
            allLists: listsVM.filteredPlaceLists,
            currentIndex: flatIndex ?? 0,
            placeCount: listsVM.lightweightPlaceListCounts[list.list_id] ?? list.place_count,
            placeColors: $placeColors,
            onTap: {
                if let idx = flatIndex { selectedListIndex = idx }
            }
        )
        .contextMenu {
            Button(role: .destructive) {
                listToDelete = list
                showDeleteConfirmation = true
            } label: {
                Label("Delete List", systemImage: "trash")
            }
        }
        .onAppear {
            handleListAppear(list: list)
        }
    }

    // MARK: - Flat List View

    private var flatListView: some View {
        LazyVGrid(columns: listColumns, spacing: 16) {
            ForEach(Array(listsVM.filteredPlaceLists.enumerated()), id: \.element.id) { index, list in
                LightweightProfileListSection(
                    list: list,
                    places: listsVM.lightweightPlaceListPlaces[list.list_id] ?? [],
                    allLists: listsVM.filteredPlaceLists,
                    currentIndex: index,
                    placeCount: listsVM.lightweightPlaceListCounts[list.list_id] ?? list.place_count,
                    placeColors: $placeColors,
                    onTap: { selectedListIndex = index }
                )
                .contextMenu {
                    Button(role: .destructive) {
                        listToDelete = list
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete List", systemImage: "trash")
                    }
                }
                .onAppear {
                    handleListAppear(list: list)
                }
            }

            // Pagination trigger - always present at end of list to catch fast scrolling
            if listsVM.hasMorePlaceLists && !listsVM.isLoadingMorePlaceLists {
                Color.clear
                    .frame(height: 1)
                    .onAppear {
                        Task {
                            await listsVM.loadMoreLists()
                        }
                    }
            }

            // Pagination loading indicator
            if listsVM.isLoadingMorePlaceLists {
                paginationLoadingView
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Pagination Trigger

    @ViewBuilder
    private var paginationTrigger: some View {
        if listsVM.hasMorePlaceLists && !listsVM.isLoadingMorePlaceLists {
            Color.clear
                .frame(height: 1)
                .onAppear {
                    Task {
                        await listsVM.loadMoreLists()
                    }
                }
        }

        if listsVM.isLoadingMorePlaceLists {
            paginationLoadingView
        }
    }

    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        Group {
            if listsVM.showOnlySharedLists {
                noSharedListsView
            } else {
                createListTileGrid
            }
        }
    }
    
    private var noSharedListsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2")
                .font(.system(size: 32))
                .foregroundColor(.gray.opacity(0.5))
            Text("No shared lists")
                .font(.subheadline)
                .foregroundColor(.gray)
            Text("Lists shared with you or that you've shared will appear here")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
        .padding(.vertical, 20)
    }
    
    private var createListTileGrid: some View {
        LazyVGrid(columns: listColumns, spacing: 16) {
            CreateListTileView(onTap: {
                showingNewListSheet = true
            })
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Pagination Loading View
    
    private var paginationLoadingView: some View {
        HStack {
            Spacer()
            ProgressView()
                .padding()
            Spacer()
        }
    }
    
    // MARK: - Actions

    /// Called when list popup sheet is dismissed - navigates to map if user tapped "Map".
    private func handleListPopupDismiss() {
        guard let listId = pendingMapListId else { return }
        pendingMapListId = nil
        profile.selectedListIdForMap = listId
        presentationMode.wrappedValue.dismiss()
    }

    /// Handle list appearing - triggers pagination when approaching end
    private func handleListAppear(list: LightweightPlaceList) {
        // Don't paginate during search or shared filter
        guard !listsVM.showOnlySharedLists && listsVM.listSearchText.isEmpty else { return }

        if listsVM.shouldLoadMoreLists(
            currentItem: list,
            filteredLists: listsVM.filteredPlaceLists,
            isSearching: !listsVM.listSearchText.isEmpty
        ) {
            Task {
                await listsVM.loadMoreLists()
            }
        }
    }
}
