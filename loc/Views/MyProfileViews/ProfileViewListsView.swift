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
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var userSession: UserSession
    @Environment(\.presentationMode) private var presentationMode

    @State private var showingImagePicker = false
    @State private var inputImage: [UIImage] = []
    @State private var selectedList: PlaceListViewModel?
    @State private var showingNewListSheet = false
    @State private var placeColors: [UUID: Color] = [:]
    @FocusState private var isSearchFocused: Bool
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerView
            
            ScrollViewReader { proxy in
                VStack(alignment: .leading, spacing: 8) {
                    if profile.isSearchingLists {
                        searchBar
                            .id("searchBar")
                    }
                    
                    listContent
                }
                .onChange(of: isSearchFocused) { focused in
                    if focused {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo("searchBar", anchor: .top)
                        }
                    }
                }
            }
        }
        .onChange(of: profile.isSearchingLists) { isSearching in
            if isSearching {
                isSearchFocused = true
            } else {
                isSearchFocused = false
                profile.listSearchText = ""
                Task {
                    await profile.reloadListsAfterSearch()
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
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        ListHeaderView(
            showOnlyShared: profile.showOnlySharedLists,
            hasSharedLists: profile.hasSharedLists,
            isFilterEnabled: profile.canInteractWithSharedFilter,
            isSearching: profile.isSearchingLists,
            onToggleFilter: {
                profile.showOnlySharedLists.toggle()
            },
            onToggleSearch: {
                withAnimation {
                    profile.isSearchingLists.toggle()
                }
            },
            onAddList: {
                showingNewListSheet = true
            }
        )
    }
    
    // MARK: - Search Bar
    
    /// Inline search bar with keyboard focus tracking for automatic scrolling
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .font(.system(size: 14))
            
            TextField("Search lists...", text: $profile.listSearchText)
                .font(.subheadline)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($isSearchFocused)
            
            if !profile.listSearchText.isEmpty {
                Button {
                    profile.listSearchText = ""
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
    }
    
    // MARK: - List Content (State-based rendering)
    
    @ViewBuilder
    private var listContent: some View {
        if profile.isLoadingInitialLists {
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
                    places: profile.lightweightPlaceListPlaces[list.list_id] ?? [],
                    allLists: profile.filteredPlaceLists,
                    currentIndex: index,
                    placeColors: $placeColors
                )
                .onAppear {
                    handleListAppear(list: list)
                }
            }
            
            // Pagination loading indicator
            if profile.isLoadingMorePlaceLists {
                paginationLoadingView
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        Group {
            if profile.showOnlySharedLists {
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
        guard !profile.showOnlySharedLists && !profile.isSearchingLists else { return }
        
        if profile.shouldLoadMorePlaceLists(
            currentItem: list,
            filteredLists: profile.filteredPlaceLists,
            isSearching: profile.isSearchingLists
        ) {
            Task {
                await dataManager.loadMorePlaceLists(userId: userSession.currentUserId ?? "")
            }
        }
    }
}
