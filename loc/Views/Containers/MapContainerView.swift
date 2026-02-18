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
    @ObservedObject private var presentationService = PresentationService.shared
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
            .onChange(of: presentationService.activeSheet) { oldSheet, newSheet in
                // Clear filters when a filter-related sheet is dismissed
                guard newSheet == nil,
                      let oldSheet = oldSheet,
                      mapViewModel.isFilterRelatedSheet(oldSheet) else { return }

                mapViewModel.clearAllFilters()

                if let userId = userSession.currentUserId,
                   let region = appCoordinator.currentMapRegion {
                    Task {
                        await mapViewModel.onMapCameraSettled(region, userId: userId)
                    }
                }
            }
        }
    }

    // MARK: - Profile onChange Handlers

    /// Handles list selection changes from ProfileViewModel
    private func handleListSelectionChange(_ newValue: String?) {
        if let listId = newValue {
            // Apply filter only — sheet presentation is handled by MainView's
            // fullScreenCover onDismiss to avoid presenting over the profile
            mapViewModel.applyListFilter(listId, availableLists: profileViewModel.listsViewModel.lightweightPlaceLists)

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
            // Dismiss any competing sheets via PresentationService
            PresentationService.shared.dismiss()
            selectedPlaceViewModel.selectedPlace = nil
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
            // Dismiss any competing sheets via PresentationService
            PresentationService.shared.dismiss()
            selectedPlaceViewModel.selectedPlace = nil
            mapDisplayCoordinatorViewModel.showExternalListOnMap = nil

            let photoUrl = mapDisplayCoordinatorViewModel.mapDisplayUserPhotoUrl.flatMap { URL(string: $0) }
            mapViewModel.selectExternalList(listId: listId, userId: userId, userPhotoUrl: photoUrl)

            if let listCenter = mapDisplayCoordinatorViewModel.mapDisplayLists
                .first(where: { $0.list_id == listId })?.averageLocation {
                withAnimation(.easeInOut(duration: 0.5)) {
                    mapPosition = .region(MKCoordinateRegion(
                        center: listCenter,
                        span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
                    ))
                }
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
            // Dismiss any competing sheets via PresentationService
            PresentationService.shared.dismiss()
            selectedPlaceViewModel.selectedPlace = nil
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
    @ObservedObject var appCoordinator: AppCoordinator
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
            // Dismiss any map popup via PresentationService
            if PresentationService.shared.isShowingMapPopup {
                PresentationService.shared.dismiss()
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
