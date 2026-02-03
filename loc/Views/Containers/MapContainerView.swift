//
//  MapContainerView.swift
//  loc
//
//  Created by Cursor on 11/13/25.
//

import SwiftUI
import MapKit

/// Container that owns MapViewModel and handles all map-related logic
struct MapContainerView: View {
    @StateObject private var mapViewModel: MapViewModel
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var appCoordinator: AppCoordinator

    @Binding var mapPosition: MapCameraPosition
    @Binding var recenterMap: Bool
    @Binding var isCreatePlacePopupActive: Bool

    let selectedPlaceViewModel: SelectedPlaceViewModel
    let detailPlaceViewModel: DetailPlaceViewModel
    let profileViewModel: ProfileViewModel
    let dataManager: DataManager
    let userProfileNavigationViewModel: UserProfileNavigationViewModel
    let mapDisplayCoordinatorViewModel: MapDisplayCoordinatorViewModel
    let serviceContainer: ServiceContainer
    let notificationManager: NotificationManager
    let onMapTap: () -> Void

    init(
        mapPosition: Binding<MapCameraPosition>,
        recenterMap: Binding<Bool>,
        isCreatePlacePopupActive: Binding<Bool>,
        selectedPlaceViewModel: SelectedPlaceViewModel,
        detailPlaceViewModel: DetailPlaceViewModel,
        placeService: PlaceService,
        profileViewModel: ProfileViewModel,
        dataManager: DataManager,
        userProfileNavigationViewModel: UserProfileNavigationViewModel,
        mapDisplayCoordinatorViewModel: MapDisplayCoordinatorViewModel,
        serviceContainer: ServiceContainer,
        notificationManager: NotificationManager,
        onMapTap: @escaping () -> Void
    ) {
        self._mapPosition = mapPosition
        self._recenterMap = recenterMap
        self._isCreatePlacePopupActive = isCreatePlacePopupActive
        self.selectedPlaceViewModel = selectedPlaceViewModel
        self.detailPlaceViewModel = detailPlaceViewModel
        self.profileViewModel = profileViewModel
        self.dataManager = dataManager
        self.userProfileNavigationViewModel = userProfileNavigationViewModel
        self.mapDisplayCoordinatorViewModel = mapDisplayCoordinatorViewModel
        self.serviceContainer = serviceContainer
        self.notificationManager = notificationManager
        self.onMapTap = onMapTap

        // Create MapViewModel scoped to this container
        // Note: MapViewModel no longer observes ProfileViewModel directly
        // The View layer coordinates data flow between ViewModels (SRP pattern)
        let mapVM = MapViewModel(
            placeService: placeService,
            detailPlaceVM: detailPlaceViewModel
        )

        self._mapViewModel = StateObject(wrappedValue: mapVM)
    }

    var body: some View {
        mapContent
            .ignoresSafeArea()
            .edgesIgnoringSafeArea(.all)
            .modifier(ExternalProfileOnChangeModifiers(
                mapDisplayCoordinatorViewModel: mapDisplayCoordinatorViewModel,
                selectedPlaceViewModel: selectedPlaceViewModel,
                mapViewModel: mapViewModel,
                appCoordinator: appCoordinator,
                userSession: userSession,
                mapPosition: $mapPosition
            ))
            .modifier(SheetOnChangeModifiers(
                selectedPlaceViewModel: selectedPlaceViewModel,
                userProfileNavigationViewModel: userProfileNavigationViewModel,
                mapViewModel: mapViewModel,
                appCoordinator: appCoordinator,
                userSession: userSession
            ))
            .sheet(item: $mapViewModel.activeSheet) { sheetType in
                sheetContent(for: sheetType)
            }
    }

    // MARK: - Map Content with Profile Observers

    /// The main map view with profile-related onChange handlers
    private var mapContent: some View {
        ZStack {
            MapView(
                recenterMap: $recenterMap,
                mapPosition: $mapPosition,
                isCreatePlacePopupActive: $isCreatePlacePopupActive,
                onMapTap: onMapTap
            )
            .environmentObject(mapViewModel)
            .environmentObject(selectedPlaceViewModel)
            .environmentObject(detailPlaceViewModel)
            .environmentObject(profileViewModel)
            .onChange(of: profileViewModel.selectedListIdForMap) { oldValue, newValue in
                handleListSelectionChange(newValue)
            }
            .onChange(of: profileViewModel.showTikToksOnMap) { _, newValue in
                handleTikToksOnMap(newValue)
            }
            .onChange(of: profileViewModel.showReviewsOnMap) { _, newValue in
                handleReviewsOnMap(newValue)
            }
            .onChange(of: profileViewModel.showFavoritesOnMap) { _, newValue in
                handleFavoritesOnMap(newValue)
            }
            .onChange(of: profileViewModel.showMyPlacesOnMap) { _, newValue in
                handleMyPlacesOnMap(newValue)
            }
        }
    }

    // MARK: - Profile onChange Handlers

    /// Handles list selection changes from ProfileViewModel
    private func handleListSelectionChange(_ newValue: String?) {
        if let listId = newValue {
            // Dismiss any competing sheets before presenting the list sheet
            selectedPlaceViewModel.selectedPlace = nil
            selectedPlaceViewModel.isDetailSheetPresented = false

            mapViewModel.selectList(listId, availableLists: profileViewModel.listsViewModel.lightweightPlaceLists)

            if let listCenter = profileViewModel.listsViewModel.lightweightPlaceLists
                .first(where: { $0.list_id == listId })?.averageLocation {
                mapPosition = .region(MKCoordinateRegion(
                    center: listCenter,
                    span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
                ))
            }

            if let userId = userSession.currentUserId {
                Task {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    if let region = appCoordinator.currentMapRegion {
                        await mapViewModel.onMapCameraSettled(region, userId: userId)
                    }
                }
            }
        } else {
            mapViewModel.clearListFilter()
            if let userId = userSession.currentUserId {
                let currentRegion = appCoordinator.currentMapRegion
                Task {
                    if let region = currentRegion {
                        await mapViewModel.onMapCameraSettled(region, userId: userId)
                    }
                }
            }
        }
    }

    /// Handles showing TikToks on map
    private func handleTikToksOnMap(_ newValue: Bool) {
        if newValue {
            // Dismiss any competing sheets before presenting
            selectedPlaceViewModel.selectedPlace = nil
            selectedPlaceViewModel.isDetailSheetPresented = false

            mapViewModel.selectTikToks()
            profileViewModel.showTikToksOnMap = false
            if let userId = userSession.currentUserId {
                let currentRegion = appCoordinator.currentMapRegion
                Task {
                    if let region = currentRegion {
                        await mapViewModel.onMapCameraSettled(region, userId: userId)
                    }
                }
            }
        }
    }

    /// Handles showing reviews on map
    private func handleReviewsOnMap(_ newValue: Bool) {
        if newValue {
            // Dismiss any competing sheets before presenting
            selectedPlaceViewModel.selectedPlace = nil
            selectedPlaceViewModel.isDetailSheetPresented = false

            mapViewModel.selectReviews()
            profileViewModel.showReviewsOnMap = false
            if let userId = userSession.currentUserId {
                let currentRegion = appCoordinator.currentMapRegion
                Task {
                    if let region = currentRegion {
                        await mapViewModel.onMapCameraSettled(region, userId: userId)
                    }
                }
            }
        }
    }

    /// Handles showing favorites on map
    private func handleFavoritesOnMap(_ newValue: Bool) {
        if newValue {
            // Dismiss any competing sheets before presenting
            selectedPlaceViewModel.selectedPlace = nil
            selectedPlaceViewModel.isDetailSheetPresented = false

            mapViewModel.selectFavorites()
            profileViewModel.showFavoritesOnMap = false
            if let userId = userSession.currentUserId {
                let currentRegion = appCoordinator.currentMapRegion
                Task {
                    if let region = currentRegion {
                        await mapViewModel.onMapCameraSettled(region, userId: userId)
                    }
                }
            }
        }
    }

    /// Handles showing my places on map
    private func handleMyPlacesOnMap(_ newValue: Bool) {
        if newValue {
            // Dismiss any competing sheets before presenting
            selectedPlaceViewModel.selectedPlace = nil
            selectedPlaceViewModel.isDetailSheetPresented = false

            mapViewModel.selectMyPlaces()
            profileViewModel.showMyPlacesOnMap = false
            if let userId = userSession.currentUserId {
                let currentRegion = appCoordinator.currentMapRegion
                Task {
                    if let region = currentRegion {
                        await mapViewModel.onMapCameraSettled(region, userId: userId)
                    }
                }
            }
        }
    }

    // MARK: - Sheet Content

    /// Builds the sheet content for a given sheet type
    @ViewBuilder
    private func sheetContent(for sheetType: MapSheetType) -> some View {
        Group {
            switch sheetType {
            case .list(let listId):
                listSheetContent(listId: listId)

            case .tiktoks:
                TikToksPopupView()

            case .reviews:
                ReviewsListPopupView()

            case .favorites:
                FavoritesPopupView()

            case .myPlaces:
                MyPlacesListView()

            case .externalReviews:
                ExternalReviewsListPopupView(
                    mapDisplayCoordinatorVM: mapDisplayCoordinatorViewModel,
                    userProfileNavigationVM: userProfileNavigationViewModel
                )

            case .externalList(let listId):
                externalListSheetContent(listId: listId)

            case .externalFavorites:
                ExternalFavoritesListPopupView(
                    mapDisplayCoordinatorVM: mapDisplayCoordinatorViewModel,
                    userProfileNavigationVM: userProfileNavigationViewModel
                )

            case .keywordResults(let keyword, let types):
                KeywordResultsPopupView(keyword: keyword, types: types)
            }
        }
        .environmentObject(profileViewModel)
        .environmentObject(selectedPlaceViewModel)
        .environmentObject(detailPlaceViewModel)
        .environmentObject(mapViewModel)
        .environmentObject(dataManager)
        .environmentObject(locationManager)
        .environmentObject(userSession)
        .environmentObject(userProfileNavigationViewModel)
        .environmentObject(mapDisplayCoordinatorViewModel)
        .environmentObject(serviceContainer)
        .environmentObject(notificationManager)
        .presentationDetents([.height(300), .height(800)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.clear)
        .presentationBackgroundInteraction(.enabled(upThrough: .height(800)))
        .onDisappear {
            handleSheetDisappear()
        }
    }

    /// Builds content for list sheet
    @ViewBuilder
    private func listSheetContent(listId: String) -> some View {
        if let listIndex = profileViewModel.listsViewModel.lightweightPlaceLists.firstIndex(where: { $0.id == listId }) {
            LightweightListPopupView(
                lists: profileViewModel.listsViewModel.lightweightPlaceLists,
                initialListIndex: listIndex
            )
            .id(listId)
        } else {
            loadingListView
        }
    }

    /// Builds content for external list sheet
    @ViewBuilder
    private func externalListSheetContent(listId: String) -> some View {
        if let listIndex = mapDisplayCoordinatorViewModel.mapDisplayLists.firstIndex(where: { $0.list_id == listId }) {
            let popupViewModel = ExternalListPopupViewModel(
                lists: mapDisplayCoordinatorViewModel.mapDisplayLists,
                initialListIndex: listIndex,
                preloadedPlaces: mapDisplayCoordinatorViewModel.mapDisplayListPlaces
            )
            ExternalUserLightweightListPopupView(
                viewModel: popupViewModel,
                showBackToProfileButton: true,
                mapViewModel: mapViewModel
            )
        } else {
            loadingListView
        }
    }

    /// Loading view for lists
    private var loadingListView: some View {
        VStack {
            ProgressView()
                .padding()
            Text("Loading list...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Handles sheet disappear
    private func handleSheetDisappear() {
        mapViewModel.clearAllFilters()
        profileViewModel.selectedListIdForMap = nil

        if let userId = userSession.currentUserId {
            let currentRegion = appCoordinator.currentMapRegion
            Task {
                if let region = currentRegion {
                    await mapViewModel.onMapCameraSettled(region, userId: userId)
                }
            }
        }
    }
}

// MARK: - External Profile onChange Modifiers

/// Extracted view modifier for external profile onChange handlers
private struct ExternalProfileOnChangeModifiers: ViewModifier {
    @ObservedObject var mapDisplayCoordinatorViewModel: MapDisplayCoordinatorViewModel
    let selectedPlaceViewModel: SelectedPlaceViewModel
    let mapViewModel: MapViewModel
    let appCoordinator: AppCoordinator
    let userSession: UserSession
    @Binding var mapPosition: MapCameraPosition

    func body(content: Content) -> some View {
        content
            .onChange(of: mapDisplayCoordinatorViewModel.showExternalReviewsOnMap) { _, shouldShow in
                handleExternalReviewsOnMap(shouldShow)
            }
            .onChange(of: mapDisplayCoordinatorViewModel.showExternalListOnMap) { _, listId in
                handleExternalListOnMap(listId)
            }
            .onChange(of: mapDisplayCoordinatorViewModel.showExternalFavoritesOnMap) { _, shouldShow in
                handleExternalFavoritesOnMap(shouldShow)
            }
    }

    /// Handles external reviews on map
    private func handleExternalReviewsOnMap(_ shouldShow: Bool) {
        if shouldShow, let userId = mapDisplayCoordinatorViewModel.mapDisplayUserId {
            // Dismiss any competing sheets and present the external reviews sheet
            selectedPlaceViewModel.selectedPlace = nil
            selectedPlaceViewModel.isDetailSheetPresented = false
            mapDisplayCoordinatorViewModel.showExternalReviewsOnMap = false

            let photoUrl = mapDisplayCoordinatorViewModel.mapDisplayUserPhotoUrl.flatMap { URL(string: $0) }
            mapViewModel.selectExternalReviews(userId: userId, userPhotoUrl: photoUrl)

            if let currentUserId = userSession.currentUserId {
                let currentRegion = appCoordinator.currentMapRegion
                Task {
                    if let region = currentRegion {
                        await mapViewModel.onMapCameraSettled(region, userId: currentUserId)
                    }
                }
            }
        }
    }

    /// Handles external list on map
    private func handleExternalListOnMap(_ listId: String?) {
        if let listId = listId, let userId = mapDisplayCoordinatorViewModel.mapDisplayUserId {
            // Dismiss any competing sheets and present the external list sheet
            selectedPlaceViewModel.selectedPlace = nil
            selectedPlaceViewModel.isDetailSheetPresented = false
            mapDisplayCoordinatorViewModel.showExternalListOnMap = nil

            let photoUrl = mapDisplayCoordinatorViewModel.mapDisplayUserPhotoUrl.flatMap { URL(string: $0) }
            mapViewModel.selectExternalList(listId: listId, userId: userId, userPhotoUrl: photoUrl)

            if let listCenter = mapDisplayCoordinatorViewModel.mapDisplayLists
                .first(where: { $0.list_id == listId })?.averageLocation {
                mapPosition = .region(MKCoordinateRegion(
                    center: listCenter,
                    span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
                ))
            }

            if let currentUserId = userSession.currentUserId {
                Task {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    if let newRegion = appCoordinator.currentMapRegion {
                        await mapViewModel.onMapCameraSettled(newRegion, userId: currentUserId)
                    }
                }
            }
        }
    }

    /// Handles external favorites on map
    private func handleExternalFavoritesOnMap(_ shouldShow: Bool) {
        if shouldShow, let userId = mapDisplayCoordinatorViewModel.mapDisplayUserId {
            // Dismiss any competing sheets and present the external favorites sheet
            selectedPlaceViewModel.selectedPlace = nil
            selectedPlaceViewModel.isDetailSheetPresented = false
            mapDisplayCoordinatorViewModel.showExternalFavoritesOnMap = false

            let photoUrl = mapDisplayCoordinatorViewModel.mapDisplayUserPhotoUrl.flatMap { URL(string: $0) }
            mapViewModel.selectExternalFavorites(userId: userId, userPhotoUrl: photoUrl)

            if let currentUserId = userSession.currentUserId {
                let currentRegion = appCoordinator.currentMapRegion
                Task {
                    if let region = currentRegion {
                        await mapViewModel.onMapCameraSettled(region, userId: currentUserId)
                    }
                }
            }
        }
    }
}

// MARK: - Sheet onChange Modifiers

/// Extracted view modifier for sheet-related onChange handlers
private struct SheetOnChangeModifiers: ViewModifier {
    let selectedPlaceViewModel: SelectedPlaceViewModel
    @ObservedObject var userProfileNavigationViewModel: UserProfileNavigationViewModel
    let mapViewModel: MapViewModel
    let appCoordinator: AppCoordinator
    let userSession: UserSession

    func body(content: Content) -> some View {
        content
            .onChange(of: selectedPlaceViewModel.isDetailSheetPresented) { oldValue, newValue in
                // Monitor detail sheet presentation state for debugging if needed
            }
            .onChange(of: userProfileNavigationViewModel.isUserDetailPresented) { _, isPresented in
                handleUserDetailPresented(isPresented)
            }
            .onChange(of: appCoordinator.showKeywordResultsPopup) { _, shouldShow in
                handleKeywordResultsPopup(shouldShow)
            }
    }

    /// Handles user detail presentation
    private func handleUserDetailPresented(_ isPresented: Bool) {
        if isPresented {
            if !userProfileNavigationViewModel.navigatedFromPlaceDetail {
                selectedPlaceViewModel.selectedPlace = nil
            }
            if mapViewModel.activeSheet != nil {
                mapViewModel.activeSheet = nil
            }
        }
    }

    /// Handles keyword results popup
    private func handleKeywordResultsPopup(_ shouldShow: Bool) {
        if shouldShow, let keyword = appCoordinator.keywordForPopup {
            mapViewModel.selectKeywordResults(
                keyword: keyword,
                types: appCoordinator.keywordTypesForPopup
            )
            appCoordinator.showKeywordResultsPopup = false

            if let userId = userSession.currentUserId {
                let currentRegion = appCoordinator.currentMapRegion
                Task {
                    if let region = currentRegion {
                        await mapViewModel.onMapCameraSettled(region, userId: userId)
                    }
                }
            }
        }
    }
}
