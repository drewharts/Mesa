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
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerView
            listContent
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(images: $inputImage, selectionLimit: 1)
        }
        .sheet(isPresented: $showingNewListSheet) {
            NewListView(isPresented: $showingNewListSheet, onSave: { listName in
                let _ = await profile.addNewPlaceList(named: listName, city: "", emoji: "", image: "")
            })
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
            onToggleFilter: {
                profile.showOnlySharedLists.toggle()
            },
            onAddList: {
                showingNewListSheet = true
            }
        )
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
    
    private var listView: some View {
        LazyVStack(spacing: 16) {
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
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            if profile.showOnlySharedLists {
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
            } else {
                Text("No lists available")
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 20)
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
        // Only paginate in unfiltered view (shared lists are fully loaded)
        guard !profile.showOnlySharedLists else { return }
        
        if profile.shouldLoadMorePlaceLists(
            currentItem: list,
            filteredLists: profile.filteredPlaceLists,
            isSearching: false
        ) {
            Task {
                await dataManager.loadMorePlaceLists(userId: userSession.currentUserId ?? "")
            }
        }
    }
}
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(images: $inputImage, selectionLimit: 1)
        }
        .sheet(isPresented: $showingNewListSheet) {
            NewListView(isPresented: $showingNewListSheet, onSave: { listName in
                let _ = await profile.addNewPlaceList(named: listName, city: "", emoji: "", image: "")
                // Result is ignored here - user will see the list appear in their profile
            })
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
    
}
