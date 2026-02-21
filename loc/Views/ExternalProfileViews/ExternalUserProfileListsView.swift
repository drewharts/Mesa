//
//  ExternalUserProfileListsView.swift
//  loc
//
//  Displays place lists for external user profiles.
//  Uses shared ProfileListCard component for consistent UI.
//

import SwiftUI

/// Wrapper to make Int identifiable for sheet presentation.
struct IdentifiableInt: Identifiable {
    let id: Int
    var value: Int { id }
}

/// Displays a user's place lists with lazy loading.
struct ExternalUserProfileListsView: View {
    @ObservedObject var viewModel: ExternalUserProfileViewModel
    let placeLists: [LightweightPlaceList]

    @State private var placeColors: [UUID: Color] = [:]
    @State private var selectedListItem: IdentifiableInt?

    // Environment objects needed for place detail navigation
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var userProfileNavigationVM: UserProfileNavigationViewModel
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var mapDisplayCoordinatorVM: MapDisplayCoordinatorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader

            if viewModel.isSearchingLists {
                searchBar
            }

            listContent
        }
        .onChange(of: viewModel.isSearchingLists) { _, isSearching in
            if !isSearching {
                viewModel.listSearchText = ""
                Task {
                    await viewModel.reloadListsAfterSearch()
                }
            }
        }
        .sheet(isPresented: $viewModel.shouldShowListPopup, onDismiss: {
            viewModel.onListPopupDismissed()
        }) {
            deepLinkListPopup
        }
        .sheet(item: $selectedListItem) { item in
            if item.value < placeLists.count {
                ExternalUserListPopupView(
                    viewModel: viewModel,
                    lists: placeLists,
                    initialListIndex: item.value,
                    placeColors: $placeColors
                )
                .environmentObject(selectedPlaceVM)
                .environmentObject(profile)
                .environmentObject(locationManager)
                .environmentObject(userProfileNavigationVM)
                .environmentObject(userSession)
                .environmentObject(detailPlaceViewModel)
                .environmentObject(ServiceContainer.shared)
                .environmentObject(dataManager)
                .environmentObject(mapDisplayCoordinatorVM)
            }
        }
    }

    // MARK: - View Components

    /// Header with "Lists" label and search toggle button.
    private var sectionHeader: some View {
        HStack {
            Text("Lists")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            Spacer()

            Button {
                withAnimation {
                    viewModel.isSearchingLists.toggle()
                }
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(viewModel.isSearchingLists ? .white : .gray)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(viewModel.isSearchingLists ? Color.primary : Color(.systemGray5)))
                    .contentShape(Circle())
            }
        }
        .padding(.horizontal, 16)
    }

    /// Inline search bar for filtering lists by name.
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .font(.system(size: 14))

            TextField("Search lists...", text: $viewModel.listSearchText)
                .font(.subheadline)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !viewModel.listSearchText.isEmpty {
                Button {
                    viewModel.listSearchText = ""
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
                        selectedListItem = IdentifiableInt(id: index)
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
            .environmentObject(profile)
            .environmentObject(locationManager)
            .environmentObject(userProfileNavigationVM)
            .environmentObject(userSession)
            .environmentObject(detailPlaceViewModel)
            .environmentObject(ServiceContainer.shared)
            .environmentObject(dataManager)
            .environmentObject(mapDisplayCoordinatorVM)
        }
    }

    // MARK: - Event Handlers

    /// Handles list appearing - loads places and triggers pagination if needed.
    private func handleListAppear(_ list: LightweightPlaceList) {
        // Lazy load places for this list if not loaded yet
        if viewModel.placeListPlaces[list.list_id] == nil {
            viewModel.loadPlacesForList(list)
        }

        // Don't paginate during search
        guard !viewModel.isSearchingLists else { return }

        // Use child ViewModel's shouldLoadMoreLists check (triggers at last 5 items)
        if viewModel.listsLoadingViewModel.shouldLoadMoreLists(
            currentItem: list,
            allLists: placeLists
        ) {
            viewModel.fetchMoreLists()
        }
    }
}

// MARK: - External User List Popup View

struct ExternalUserListPopupView: View {
    @ObservedObject var viewModel: ExternalUserProfileViewModel
    let lists: [LightweightPlaceList]
    let initialListIndex: Int
    @Binding var placeColors: [UUID: Color]

    // Environment objects needed to flow through to PlaceDetailViewInNavigation
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var userProfileNavigationVM: UserProfileNavigationViewModel
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @EnvironmentObject var mapDisplayCoordinatorVM: MapDisplayCoordinatorViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var currentListIndex: Int
    @State private var isLoadingMore: Bool = false
    @State private var hasMorePlaces: Bool = true
    @State private var currentPage: Int = 1
    @State private var navigationPath = NavigationPath()
    @State private var isLoadingInitial: Bool = true

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
                is_public: true,
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
                dismissButton
                Spacer()
                viewOnMapButton
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

    /// Button that dismisses the list popup sheet.
    private var dismissButton: some View {
        Button(action: {
            presentationMode.wrappedValue.dismiss()
        }) {
            Image(systemName: "xmark")
                .font(.body)
                .foregroundColor(.gray)
        }
    }

    /// Button that dismisses the profile and shows this list's places on the map.
    private var viewOnMapButton: some View {
        Button(action: {
            let list = currentList
            let navVM = userProfileNavigationVM
            mapDisplayCoordinatorVM.triggerExternalListOnMap(
                listId: list.list_id,
                userId: viewModel.userId,
                userName: viewModel.user.fullName,
                userPhotoUrl: viewModel.user.profilePhotoURL?.absoluteString,
                lists: lists,
                listPlaces: viewModel.placeListPlaces,
                dismissProfile: { navVM.clearSelection() }
            )
        }) {
            Image(systemName: "map")
                .font(.body)
                .foregroundColor(.gray)
        }
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
                        isLoadingInitial: $isLoadingInitial,
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
                isLoadingInitial: $isLoadingInitial,
                onLoadMore: { loadMoreIfNeeded() },
                onNavigateToPlace: { placeId in
                    navigationPath.append(placeId)
                }
            )
        }
    }

    // MARK: - Data Loading

    /// Loads places for the current list if not already loaded or empty.
    private func loadPlacesIfNeeded() {
        let list = lists[currentListIndex]
        let existingPlaces = viewModel.placeListPlaces[list.list_id]

        // Load if nil OR empty (empty array might exist from failed previous attempt)
        if existingPlaces == nil || existingPlaces?.isEmpty == true {
            isLoadingInitial = true
            viewModel.loadPlacesForList(list)
        } else {
            isLoadingInitial = false
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
    @Binding var isLoadingInitial: Bool
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
                        PopupPlaceCard(
                            place: place,
                            preferExternalThumbnail: true,
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
            .onAppear {
                // Places loaded, clear loading state
                if isLoadingInitial {
                    isLoadingInitial = false
                }
            }
        } else if isLoadingInitial {
            VStack(spacing: 12) {
                Spacer()
                ProgressView()
                    .scaleEffect(1.2)
                Text("Loading places...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
