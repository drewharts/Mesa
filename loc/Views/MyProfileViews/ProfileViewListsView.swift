//
//  ProfileViewListsView.swift
//  loc
//
//  DUMB Component: Displays user's place lists with preview cards and a search tap target.
//  Tapping the search bar opens FullScreenListsView for dedicated search and browsing.
//
//  Created by Andrew Hartsfield II on 12/14/24.
//

import SwiftUI

struct ProfileViewListsView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var deepLinkManager: DeepLinkManager
    @EnvironmentObject var userSession: UserSession
    @ObservedObject var listsVM: ProfileListsViewModel
    @Environment(\.presentationMode) private var presentationMode

    @State private var placeColors: [UUID: Color] = [:]
    @State private var showFullScreenLists = false
    @State private var showingNewListSheet = false
    @State private var showingCreateTrip = false
    @State private var showingGoogleMapsImport = false
    @State private var selectedListIndex: Int? = nil
    @State private var pendingMapListId: String? = nil

    private let listColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            searchBarTapTarget
            listContent
        }
        .fullScreenCover(isPresented: $showFullScreenLists) {
            FullScreenListsView(listsVM: listsVM)
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
                onImportCompleted: { _ in
                    Task { await listsVM.reloadListsAfterSearch() }
                }
            )
        }
        .fullScreenCover(isPresented: $showingCreateTrip) {
            CreateTripView { _ in showingCreateTrip = false }
                .environmentObject(userSession)
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
        .onChange(of: profile.selectedListIdForMap) { _, newValue in
            if newValue != nil {
                showFullScreenLists = false
                presentationMode.wrappedValue.dismiss()
            }
        }
        .sheet(item: Binding<ListCardIndex?>(
            get: { selectedListIndex.map { ListCardIndex(value: $0) } },
            set: { selectedListIndex = $0?.value }
        ), onDismiss: {
            guard let listId = pendingMapListId else { return }
            pendingMapListId = nil
            profile.selectedListIdForMap = listId
            presentationMode.wrappedValue.dismiss()
        }) { item in
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

    // MARK: - Search Bar Tap Target

    /// Non-editable search bar that opens the full-screen lists view when tapped.
    private var searchBarTapTarget: some View {
        HStack(spacing: 10) {
            Button { showFullScreenLists = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                        .font(.system(size: 14))

                    Text("Search lists...")
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color(.systemGray5).opacity(0.6))
                )
            }

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
        if listsVM.isLoadingInitialLists {
            initialLoadingView
        } else if !listsVM.filteredPlaceLists.isEmpty {
            ListCardGrid(
                listsVM: listsVM,
                placeColors: $placeColors,
                userId: profile.user?.id ?? "",
                onListTap: { index in selectedListIndex = index }
            )
        } else {
            createListTile
        }
    }

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

    private var createListTile: some View {
        LazyVGrid(columns: listColumns, spacing: 16) {
            CreateListTileView(onTap: { showingNewListSheet = true })
        }
        .padding(.horizontal, 16)
    }
}
