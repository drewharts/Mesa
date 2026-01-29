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

struct ProfileViewListsView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @EnvironmentObject var deepLinkManager: DeepLinkManager
    @Environment(\.presentationMode) private var presentationMode

    /// Convenience accessor for lists view model.
    private var listsVM: ProfileListsViewModel { profile.listsViewModel }

    @State private var showingImagePicker = false
    @State private var inputImage: [UIImage] = []
    @State private var selectedList: PlaceListViewModel?
    @State private var showingNewListSheet = false
    @State private var placeColors: [UUID: Color] = [:]
    @State private var listToDelete: LightweightPlaceList?
    @State private var showDeleteConfirmation = false

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerView

            // Simple inline search bar
            if listsVM.isSearchingLists {
                searchBar
            }

            listContent
        }
        .onChange(of: listsVM.isSearchingLists) { isSearching in
            if !isSearching {
                listsVM.listSearchText = ""
                Task {
                    await listsVM.reloadListsAfterSearch()
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(images: $inputImage, selectionLimit: 1)
        }
        .sheet(isPresented: $showingNewListSheet) {
            NewListSheetView(onSave: { listName in
                let _ = await profile.addNewPlaceList(named: listName, city: "", emoji: "", image: "")
            })
            .presentationDetents([.height(200)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: .constant(deepLinkManager.hasPendingList()), onDismiss: {
            deepLinkManager.clearPendingList()
        }) {
            if let pendingList = deepLinkManager.pendingList {
                SwipeableListPopupView(
                    lists: pendingList.lists,
                    initialListIndex: pendingList.initialIndex,
                    placeColors: $placeColors
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
                        let result = await profile.deleteLightweightList(list)
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
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        ListHeaderView(
            showOnlyShared: listsVM.showOnlySharedLists,
            hasSharedLists: profile.hasSharedLists,
            isFilterEnabled: profile.canInteractWithSharedFilter,
            isSearching: listsVM.isSearchingLists,
            onToggleFilter: {
                listsVM.showOnlySharedLists.toggle()
            },
            onToggleSearch: {
                withAnimation {
                    listsVM.isSearchingLists.toggle()
                }
            },
            onAddList: {
                showingNewListSheet = true
            }
        )
    }
    
    // MARK: - Search Bar
    
    /// Simple inline search bar for filtering lists
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .font(.system(size: 14))

            TextField("Search lists...", text: Binding(
                get: { listsVM.listSearchText },
                set: { listsVM.listSearchText = $0 }
            ))
                .font(.subheadline)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !listsVM.listSearchText.isEmpty {
                Button {
                    listsVM.listSearchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 14))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal, 20)
        .padding(.bottom, 4)
    }
    
    // MARK: - List Content (State-based rendering)
    
    @ViewBuilder
    private var listContent: some View {
        if listsVM.isLoadingInitialLists {
            // Initial loading state
            initialLoadingView
        } else if !profile.filteredPlaceLists.isEmpty {
            // Lists available
            listView
        } else {
            // Empty state
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
    
    // MARK: - List View
    
    // 2-column grid for displaying lists side by side
    private let listColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    private var listView: some View {
        LazyVGrid(columns: listColumns, spacing: 16) {
            ForEach(Array(profile.filteredPlaceLists.enumerated()), id: \.element.id) { index, list in
                LightweightProfileListSection(
                    list: list,
                    places: listsVM.lightweightPlaceListPlaces[list.list_id] ?? [],
                    allLists: profile.filteredPlaceLists,
                    currentIndex: index,
                    placeColors: $placeColors
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

            // Pagination loading indicator
            if listsVM.isLoadingMorePlaceLists {
                paginationLoadingView
            }
        }
        .padding(.horizontal, 16)
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
    
    /// Handle list appearing - triggers pagination when approaching end
    private func handleListAppear(list: LightweightPlaceList) {
        // Don't paginate during search or shared filter
        guard !listsVM.showOnlySharedLists && !listsVM.isSearchingLists else { return }

        if listsVM.shouldLoadMoreLists(
            currentItem: list,
            filteredLists: profile.filteredPlaceLists,
            isSearching: listsVM.isSearchingLists
        ) {
            Task {
                await listsVM.loadMoreLists()
            }
        }
    }
}
