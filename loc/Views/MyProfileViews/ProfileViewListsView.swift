//
//  ProfileViewListsView.swift
//  loc
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

    @StateObject private var searchVM: ListSearchViewModel
    @State private var showingImagePicker = false
    @State private var inputImage: [UIImage] = []
    @State private var selectedList: PlaceListViewModel?
    @State private var showingNewListSheet = false
    @State private var placeColors: [UUID: Color] = [:]
    
    // Initialize with dependency injection
    init() {
        // Create searchVM with proper dependencies
        // Note: EnvironmentObject values aren't available in init, so we use a wrapper
        let session = UserSession.shared
        _searchVM = StateObject(wrappedValue: ListSearchViewModel(userSession: session))
    }
    
    // ✅ STAFF ENGINEER: Separate contexts for browse vs search
    private var isSearching: Bool {
        !searchVM.searchText.isEmpty
    }
    
    private var displayedLists: [LightweightPlaceList] {
        isSearching ? searchVM.searchResults : profile.lightweightPlaceLists
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ListHeaderView(
                onAddList: {
                    showingNewListSheet = true
                },
                searchText: $searchVM.searchText
            )

            if !displayedLists.isEmpty {
                LazyVStack(spacing: 16) {
                    ForEach(Array(displayedLists.enumerated()), id: \.element.id) { index, list in
                        LightweightProfileListSection(
                            list: list,
                            places: profile.lightweightPlaceListPlaces[list.list_id] ?? [],
                            allLists: displayedLists,
                            currentIndex: index,
                            placeColors: $placeColors
                        )
                        .onAppear {
                            handlePagination(index: index, list: list)
                        }
                    }
                    
                    // Loading indicator at the bottom
                    if isSearching ? searchVM.isLoadingMore : profile.isLoadingMorePlaceLists {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding()
                            Spacer()
                        }
                    }
                }
            } else {
                emptyStateView
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
    
    // MARK: - Helper Methods
    
    /// ✅ STAFF ENGINEER: Separate pagination logic by context (browse vs search)
    private func handlePagination(index: Int, list: LightweightPlaceList) {
        if isSearching {
            // Search pagination
            if searchVM.shouldLoadMore(currentIndex: index) {
                Task {
                    await searchVM.loadMoreResults()
                }
            }
        } else {
            // Browse pagination (proximity-based)
            if profile.shouldLoadMorePlaceLists(
                currentItem: list,
                filteredLists: displayedLists,
                isSearching: false
            ) {
                Task {
                    await dataManager.loadMorePlaceLists(userId: userSession.currentUserId ?? "")
                }
            }
        }
    }
    
    /// Empty state view for different contexts
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            if searchVM.isSearching {
                ProgressView()
                    .padding()
                Text("Searching...")
                    .foregroundColor(.gray)
            } else if isSearching {
                Text("No lists found")
                    .foregroundColor(.gray)
                    .padding(.horizontal)
                Text("No lists match '\(searchVM.searchText)'")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
            } else {
                Text("No lists available")
                    .foregroundColor(.gray)
                    .padding(.horizontal)
            }
        }
    }
}
