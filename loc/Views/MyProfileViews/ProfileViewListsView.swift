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

    @State private var showingImagePicker = false
    @State private var inputImage: [UIImage] = []
    @State private var selectedList: PlaceListViewModel?
    @State private var showingNewListSheet = false
    @State private var searchText = ""
    @State private var placeColors: [UUID: Color] = [:]
    
    // Filtered lightweight lists based on search
    var filteredLists: [LightweightPlaceList] {
        let sorted = profile.lightweightPlaceLists
        if searchText.isEmpty {
            return sorted
        } else {
            return sorted.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ListHeaderView(
                onAddList: {
                    showingNewListSheet = true
                },
                searchText: $searchText
            )

            if !filteredLists.isEmpty {
                LazyVStack(spacing: 16) {
                    ForEach(Array(filteredLists.enumerated()), id: \.element.id) { index, list in
                        LightweightProfileListSection(
                            list: list,
                            places: profile.lightweightPlaceListPlaces[list.list_id] ?? [],
                            placeColors: $placeColors
                        )
                        .onAppear {
                            // Load more when we reach the 3rd-to-last item
                            if index == filteredLists.count - 3 && searchText.isEmpty {
                                loadMoreListsIfNeeded()
                            }
                        }
                    }
                    
                    // Loading indicator at the bottom
                    if profile.isLoadingMorePlaceLists {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding()
                            Spacer()
                        }
                    }
                }
            } else {
                VStack(spacing: 8) {
                    if searchText.isEmpty {
                        Text("No lists available")
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                    } else {
                        Text("No lists found")
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                        Text("No lists match '\(searchText)'")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                    }
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(images: $inputImage, selectionLimit: 1)
        }
        .sheet(isPresented: $showingNewListSheet) {
            NewListView(isPresented: $showingNewListSheet, onSave: { listName in
                profile.addNewPlaceList(named: listName, city: "", emoji: "", image: "")
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
    
    private func loadMoreListsIfNeeded() {
        guard !profile.isLoadingMorePlaceLists && profile.hasMorePlaceLists else { return }
        
        Task {
            await dataManager.loadMorePlaceLists(userId: userSession.currentUserId ?? "")
        }
    }
}
