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
                showOnlyShared: profile.showOnlySharedLists,
                hasSharedLists: profile.hasSharedLists,
                onToggleFilter: {
                    profile.showOnlySharedLists.toggle()
                },
                onAddList: {
                    showingNewListSheet = true
                }
            )

            if !profile.filteredPlaceLists.isEmpty {
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
                            // Trigger pagination when approaching the end (only for non-filtered view)
                            if !profile.showOnlySharedLists && profile.shouldLoadMorePlaceLists(
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
                // Empty state - differentiate between no lists and no filtered results
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
