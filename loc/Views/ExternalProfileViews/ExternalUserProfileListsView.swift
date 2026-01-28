//
//  ExternalUserProfileListsView.swift
//  loc
//
//  Displays place lists for external user profiles.
//  Uses shared ProfileListCard component for consistent UI.
//

import SwiftUI

/// Displays a user's place lists with lazy loading.
struct ExternalUserProfileListsView: View {
    @ObservedObject var viewModel: ExternalUserProfileViewModel
    let placeLists: [LightweightPlaceList]

    @State private var placeColors: [UUID: Color] = [:]
    @State private var selectedListIndex: Int?
    @State private var showListPopup = false
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader
            listContent
        }
        .sheet(isPresented: $viewModel.shouldShowListPopup, onDismiss: {
            viewModel.onListPopupDismissed()
        }) {
            deepLinkListPopup
        }
        .sheet(isPresented: $showListPopup) {
            if let index = selectedListIndex, index < placeLists.count {
                ExternalUserListPopupView(
                    viewModel: viewModel,
                    lists: placeLists,
                    initialListIndex: index,
                    placeColors: $placeColors
                )
                .environmentObject(selectedPlaceVM)
            }
        }
    }

    // MARK: - View Components

    private var sectionHeader: some View {
        Text("Lists")
            .font(.headline)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 16)
            .foregroundColor(.primary)
    }

    @ViewBuilder
    private var listContent: some View {
        if placeLists.isEmpty {
            emptyState
        } else {
            listItems
        }
    }

    private var emptyState: some View {
        Text("No lists available")
            .font(.subheadline)
            .foregroundColor(.gray)
            .padding(.leading, 20)
    }

    // 2-column grid for displaying lists side by side
    private let listColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var listItems: some View {
        LazyVGrid(columns: listColumns, spacing: 16) {
            ForEach(Array(placeLists.enumerated()), id: \.element.id) { index, list in
                ProfileListCard(
                    list: list,
                    places: viewModel.placeListPlaces[list.list_id] ?? [],
                    placeColors: $placeColors,
                    config: .external,
                    onTap: {
                        selectedListIndex = index
                        showListPopup = true
                    }
                )
                .onAppear {
                    handleListAppear(list)
                }
            }

            // Loading indicator for pagination
            if viewModel.isLoadingMoreLists {
                paginationLoadingIndicator
            }
        }
        .padding(.horizontal, 16)
    }

    private var paginationLoadingIndicator: some View {
        HStack {
            Spacer()
            ProgressView()
                .padding(.vertical, 16)
            Spacer()
        }
    }

    @ViewBuilder
    private var deepLinkListPopup: some View {
        if let index = viewModel.pendingListIndex, index < placeLists.count {
            ExternalUserListPopupView(
                viewModel: viewModel,
                lists: placeLists,
                initialListIndex: index,
                placeColors: $placeColors
            )
            .environmentObject(selectedPlaceVM)
        }
    }

    // MARK: - Event Handlers

    /// Handles list appearing - loads places and triggers pagination if needed.
    private func handleListAppear(_ list: LightweightPlaceList) {
        // Lazy load places for this list if not loaded yet
        if viewModel.placeListPlaces[list.list_id] == nil {
            viewModel.loadPlacesForList(list)
        }

        // Fetch more lists from backend when approaching the end
        if isNearEndOfLists(list) {
            viewModel.fetchMoreLists()
        }
    }

    /// Returns true if this list is near the end, triggering pagination.
    private func isNearEndOfLists(_ list: LightweightPlaceList) -> Bool {
        guard placeLists.count >= 3 else { return false }
        guard let currentIndex = placeLists.firstIndex(where: { $0.id == list.id }) else { return false }

        let threshold = placeLists.count - 3
        return currentIndex >= threshold
    }
}

// MARK: - External User List Popup View

struct ExternalUserListPopupView: View {
    @ObservedObject var viewModel: ExternalUserProfileViewModel
    let lists: [LightweightPlaceList]
    let initialListIndex: Int
    @Binding var placeColors: [UUID: Color]

    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var currentListIndex: Int
    @State private var isLoadingMore: Bool = false
    @State private var hasMorePlaces: Bool = true
    @State private var currentPage: Int = 1
    @State private var navigationPath = NavigationPath()

    init(viewModel: ExternalUserProfileViewModel, lists: [LightweightPlaceList], initialListIndex: Int, placeColors: Binding<[UUID: Color]>) {
        self.viewModel = viewModel
        self.lists = lists
        self.initialListIndex = initialListIndex
        self._placeColors = placeColors
        self._currentListIndex = State(initialValue: initialListIndex)
    }

    private var currentList: LightweightPlaceList {
        guard currentListIndex >= 0 && currentListIndex < lists.count else {
            return lists.first ?? LightweightPlaceList(
                list_id: "",
                name: "Unknown",
                is_public: false,
                image: nil,
                created_at: nil,
                updated_at: nil,
                distance_meters: nil,
                place_count: 0,
                city: nil
            )
        }
        return lists[currentListIndex]
    }

    private var places: [LightweightPlace] {
        viewModel.placeListPlaces[currentList.list_id] ?? []
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                popupHeader
                popupContent
            }
            .navigationBarHidden(true)
            .navigationDestination(for: String.self) { placeId in
                PlaceDetailViewInNavigation(placeId: placeId, minSheetHeight: 250)
            }
        }
        .onAppear {
            navigationPath = NavigationPath()
            loadPlacesIfNeeded()
        }
    }

    // MARK: - Popup Header

    private var popupHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Profile")
                    }
                    .foregroundColor(.primary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            VStack(spacing: 4) {
                Text(currentList.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.black)

                Text("\(currentList.place_count) place\(currentList.place_count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 10)
    }

    // MARK: - Popup Content

    @ViewBuilder
    private var popupContent: some View {
        if lists.count > 1 {
            TabView(selection: $currentListIndex) {
                ForEach(lists.indices, id: \.self) { index in
                    ExternalUserListContentScrollView(
                        list: lists[index],
                        viewModel: viewModel,
                        isLoadingMore: $isLoadingMore,
                        hasMorePlaces: $hasMorePlaces,
                        currentPage: $currentPage,
                        onLoadMore: { loadMoreIfNeeded() },
                        onNavigateToPlace: { placeId in
                            navigationPath.append(placeId)
                        }
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .onChange(of: currentListIndex) { _, newIndex in
                isLoadingMore = false
                hasMorePlaces = true
                currentPage = 1
                loadPlacesIfNeeded()
            }
        } else {
            ExternalUserListContentScrollView(
                list: currentList,
                viewModel: viewModel,
                isLoadingMore: $isLoadingMore,
                hasMorePlaces: $hasMorePlaces,
                currentPage: $currentPage,
                onLoadMore: { loadMoreIfNeeded() },
                onNavigateToPlace: { placeId in
                    navigationPath.append(placeId)
                }
            )
        }
    }

    // MARK: - Data Loading

    /// Loads places for the current list if not already loaded.
    private func loadPlacesIfNeeded() {
        let list = lists[currentListIndex]
        if viewModel.placeListPlaces[list.list_id] == nil {
            viewModel.loadPlacesForList(list)
        }
    }

    /// Loads more places when approaching end of list.
    private func loadMoreIfNeeded() {
        guard !isLoadingMore && hasMorePlaces else { return }

        isLoadingMore = true
        let nextPage = currentPage + 1

        viewModel.loadMorePlacesForList(currentList, page: nextPage) { morePlaces in
            currentPage = nextPage
            hasMorePlaces = morePlaces.count >= 6
            isLoadingMore = false
        }
    }
}

// MARK: - External User List Content Scroll View

struct ExternalUserListContentScrollView: View {
    let list: LightweightPlaceList
    @ObservedObject var viewModel: ExternalUserProfileViewModel
    @Binding var isLoadingMore: Bool
    @Binding var hasMorePlaces: Bool
    @Binding var currentPage: Int
    let onLoadMore: () -> Void
    let onNavigateToPlace: ((String) -> Void)?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var places: [LightweightPlace] {
        viewModel.placeListPlaces[list.list_id] ?? []
    }

    var body: some View {
        if !places.isEmpty {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(Array(places.enumerated()), id: \.element.id) { index, place in
                        LightweightPlaceGridCell(
                            place: place,
                            isCollaborativeList: list.isCollaborative,
                            onNavigate: { placeId in
                                onNavigateToPlace?(placeId)
                            }
                        )
                        .onAppear {
                            if index == places.count - 3 {
                                onLoadMore()
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                if isLoadingMore {
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
                Spacer()
                Text("No places in this list")
                    .foregroundColor(.gray)
                Spacer()
            }
            .padding(.vertical, 30)
        }
    }
}
