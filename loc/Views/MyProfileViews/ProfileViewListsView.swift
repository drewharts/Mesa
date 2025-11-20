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
    @State private var placeColors: [UUID: Color] = [:]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ListHeaderView(
                onAddList: {
                    showingNewListSheet = true
                }
            )

            if !profile.lightweightPlaceLists.isEmpty {
                LazyVStack(spacing: 16) {
                    ForEach(Array(profile.lightweightPlaceLists.enumerated()), id: \.element.id) { index, list in
                        LightweightProfileListSection(
                            list: list,
                            places: profile.lightweightPlaceListPlaces[list.list_id] ?? [],
                            allLists: profile.lightweightPlaceLists,
                            currentIndex: index,
                            placeColors: $placeColors
                        )
                        .onAppear {
                            // Trigger pagination when approaching the end
                            if profile.shouldLoadMorePlaceLists(
                                currentItem: list,
                                filteredLists: profile.lightweightPlaceLists,
                                isSearching: false
                            ) {
                                Task {
                                    await dataManager.loadMorePlaceLists(userId: userSession.currentUserId ?? "")
                                }
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
                    Text("No lists available")
                        .foregroundColor(.gray)
                        .padding(.horizontal)
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
