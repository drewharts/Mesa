//
//  MainView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/12/24.
//  Refactored to enterprise architecture on 11/13/25
//

import SwiftUI
import MapKit

struct MainView: View {
    // MARK: - Global Dependencies (Only 3!)
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var appCoordinator: AppCoordinator

    // MARK: - Presentation Service (singleton, observed for sheet changes)
    @ObservedObject private var presentationService = PresentationService.shared

    // MARK: - Required ViewModels (passed from parent as @ObservedObject)
    @ObservedObject var selectedPlaceVM: SelectedPlaceViewModel
    @ObservedObject var profileViewModel: ProfileViewModel
    @ObservedObject var userProfileNavigationViewModel: UserProfileNavigationViewModel
    @ObservedObject var mapDisplayCoordinatorViewModel: MapDisplayCoordinatorViewModel
    @ObservedObject var detailPlaceViewModel: DetailPlaceViewModel
    @ObservedObject var deepLinkViewModel: DeepLinkViewModel
    @ObservedObject var notificationManager: NotificationManager

    // MARK: - Pass-through ViewModels (no observation to prevent render loops)
    let searchViewModel: SearchViewModel
    let searchCoordinator: SearchCoordinatorViewModel

    let deepLinkManager: DeepLinkManager
    let dataManager: DataManager
    let serviceContainer: ServiceContainer

    // MARK: - Local UI State
    @State private var shouldNavigateToProfile = false
    @State private var shouldNavigateToFeed = false
    @State private var pendingFeedProfileUserId: String?
    @State private var showSearchPage = false
    @State private var recenterMap = false
    @State private var isCreatePlacePopupActive = false
    @State private var mapPosition = MapCameraPosition.automatic
    @State private var annotationDisplayMode: AnnotationDisplayMode = .everyone
    @State private var isSatelliteMap: Bool = false
    @State private var showTripsSheet = false

    /// Convenience accessor for external content view model.
    private var externalContentVM: ProfileExternalContentViewModel { profileViewModel.externalContentViewModel }

    /// Binding that drives the resolution error alert presentation.
    private var resolutionErrorBinding: Binding<Bool> {
        Binding(
            get: { selectedPlaceVM.resolutionErrorMessage != nil },
            set: { if !$0 { selectedPlaceVM.resolutionErrorMessage = nil } }
        )
    }

    // MARK: - Initialization
    init(
        selectedPlaceVM: SelectedPlaceViewModel,
        profileViewModel: ProfileViewModel,
        userProfileNavigationViewModel: UserProfileNavigationViewModel,
        mapDisplayCoordinatorViewModel: MapDisplayCoordinatorViewModel,
        detailPlaceViewModel: DetailPlaceViewModel,
        deepLinkViewModel: DeepLinkViewModel,
        notificationManager: NotificationManager,
        searchViewModel: SearchViewModel,
        searchCoordinator: SearchCoordinatorViewModel,
        deepLinkManager: DeepLinkManager,
        dataManager: DataManager,
        serviceContainer: ServiceContainer
    ) {
        self.selectedPlaceVM = selectedPlaceVM
        self.profileViewModel = profileViewModel
        self.userProfileNavigationViewModel = userProfileNavigationViewModel
        self.mapDisplayCoordinatorViewModel = mapDisplayCoordinatorViewModel
        self.detailPlaceViewModel = detailPlaceViewModel
        self.deepLinkViewModel = deepLinkViewModel
        self.notificationManager = notificationManager
        self.searchViewModel = searchViewModel
        self.searchCoordinator = searchCoordinator
        self.deepLinkManager = deepLinkManager
        self.dataManager = dataManager
        self.serviceContainer = serviceContainer
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Map Container - owns MapViewModel
                MapContainerView(
                    mapPosition: $mapPosition,
                    recenterMap: $recenterMap,
                    isCreatePlacePopupActive: $isCreatePlacePopupActive,
                    annotationDisplayMode: $annotationDisplayMode,
                    isSatelliteMap: $isSatelliteMap,
                    selectedPlaceViewModel: selectedPlaceVM,
                    detailPlaceViewModel: detailPlaceViewModel,
                    placeService: serviceContainer.placeService,
                    profileViewModel: profileViewModel,
                    dataManager: dataManager,
                    userProfileNavigationViewModel: userProfileNavigationViewModel,
                    mapDisplayCoordinatorViewModel: mapDisplayCoordinatorViewModel,
                    serviceContainer: serviceContainer,
                    notificationManager: notificationManager
                )

                // UI Overlay (Top Controls, FABs)
                uiOverlayLayer

                loadingOverlay
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $userProfileNavigationViewModel.isUserDetailPresented) {
                if let selectedUser = userProfileNavigationViewModel.selectedUser {
                    ExternalUserProfileViewWrapper(
                        user: selectedUser,
                        pendingListId: userProfileNavigationViewModel.pendingListIdToOpen
                    )
                    .environmentObject(profileViewModel)
                    .environmentObject(selectedPlaceVM)
                    .environmentObject(detailPlaceViewModel)
                    .environmentObject(userSession)
                    .environmentObject(userProfileNavigationViewModel)
                    .environmentObject(mapDisplayCoordinatorViewModel)
                    .environmentObject(locationManager)
                    .environmentObject(dataManager)
                }
            }
            // UNIFIED SHEET: Single sheet modifier using PresentationService
            .sheet(item: $presentationService.activeSheet) { sheetType in
                sheetContent(for: sheetType)
            }
            .onChange(of: userProfileNavigationViewModel.isUserDetailPresented) { oldValue, newValue in
                // Dismiss sheet when navigating to user profile
                if newValue && presentationService.activeSheet != nil {
                    // Preserve state if navigating from place detail context
                    if userProfileNavigationViewModel.navigatedFromPlaceDetail {
                        selectedPlaceVM.preserveStateForNavigation()
                    }
                    presentationService.preserveAndDismiss()
                }

                // Restore state when returning from profile
                if oldValue && !newValue {
                    if userProfileNavigationViewModel.navigatedFromPlaceDetail {
                        selectedPlaceVM.restoreStateAfterNavigation()
                        userProfileNavigationViewModel.navigatedFromPlaceDetail = false
                    }
                    presentationService.restorePreservedSheet()
                }
            }
            .fullScreenCover(isPresented: $shouldNavigateToProfile, onDismiss: {
                // Present pending map sheets after profile is fully dismissed
                if let listId = profileViewModel.selectedListIdForMap {
                    PresentationService.shared.present(.list(listId: listId))
                } else if let pending = profileViewModel.pendingMapFilter {
                    profileViewModel.pendingMapFilter = nil
                    switch pending {
                    case .externalPlaces: profileViewModel.showExternalPlacesOnMap = true
                    case .reviews: profileViewModel.showReviewsOnMap = true
                    case .favorites: profileViewModel.showFavoritesOnMap = true
                    case .myPlaces: profileViewModel.showMyPlacesOnMap = true
                    }
                }
            }) {
                ProfileView()
                    .environmentObject(userProfileNavigationViewModel)
                    .environmentObject(mapDisplayCoordinatorViewModel)
                    .environmentObject(deepLinkViewModel)
                    .environmentObject(selectedPlaceVM)
                    .environmentObject(detailPlaceViewModel)
                    .environmentObject(profileViewModel)
                    .environmentObject(deepLinkManager)
                    .environmentObject(dataManager)
                    .environmentObject(serviceContainer)
            }
            .fullScreenCover(isPresented: $shouldNavigateToFeed) {
                PhotoFeedView(
                    userId: userSession.currentUserId ?? "",
                    onNavigateToProfile: { userId in
                        pendingFeedProfileUserId = userId
                        shouldNavigateToFeed = false
                    }
                )
            }
            .fullScreenCover(isPresented: $showTripsSheet) {
                TripsListView()
                    .environmentObject(userSession)
                    .environmentObject(selectedPlaceVM)
                    .environmentObject(profileViewModel)
                    .environmentObject(userProfileNavigationViewModel)
                    .environmentObject(detailPlaceViewModel)
                    .environmentObject(locationManager)
            }
            .onChange(of: shouldNavigateToFeed) { _, newValue in
                guard !newValue, let userId = pendingFeedProfileUserId else { return }
                pendingFeedProfileUserId = nil
                if userId == userSession.currentUserId {
                    shouldNavigateToProfile = true
                } else {
                    userProfileNavigationViewModel.fetchAndSelectUser(
                        userId: userId,
                        currentUserId: userSession.currentUserId ?? ""
                    )
                }
            }
            .alert("No Location Found", isPresented: $deepLinkViewModel.showNoLocationAlert) {
                Button("OK") {
                    deepLinkViewModel.dismissNoLocationAlert()
                }
            } message: {
                Text(deepLinkViewModel.noLocationAlertMessage)
            }
            .alert("Error", isPresented: resolutionErrorBinding) {
                Button("OK") { selectedPlaceVM.resolutionErrorMessage = nil }
            } message: {
                Text(selectedPlaceVM.resolutionErrorMessage ?? "")
            }
        }
        .onAppear {
            locationManager.requestLocationPermission()
            // ViewModels now call PresentationService.shared directly - no wiring needed
        }
        .onChange(of: selectedPlaceVM.shouldAnimateMapToPlace) { _, newValue in
            if newValue,
               let place = selectedPlaceVM.selectedPlace,
               let coordinate = place.coordinate,
               coordinate.isValidForNavigation {
                withAnimation(.easeOut(duration: 0.25)) {
                    mapPosition = .region(MKCoordinateRegion(
                        center: coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    ))
                }
                selectedPlaceVM.shouldAnimateMapToPlace = false
            }
        }
        .onChange(of: userProfileNavigationViewModel.shouldNavigateToOwnProfile) { _, newValue in
            if newValue {
                shouldNavigateToProfile = true
                userProfileNavigationViewModel.clearOwnProfileNavigation()
            }
        }
    }

    // MARK: - Unified Sheet Content Builder

    /// Builds sheet content for any AppSheetType.
    @ViewBuilder
    private func sheetContent(for sheetType: AppSheetType) -> some View {
        Group {
            switch sheetType {
            // Place Detail
            case .placeDetail:
                placeDetailSheet

            // External Content Import
            case .externalPlaceSelection:
                externalPlaceSelectionSheet

            case .noPlacesFound(let contentUrl):
                noPlacesFoundSheet(contentUrl: contentUrl)

            case .importPlaceConfirmation(let placeId, let contentUrl):
                importPlaceConfirmationSheet(placeId: placeId, contentUrl: contentUrl)

            // Map Popups (User's Own Data)
            case .list(let listId):
                listSheet(listId: listId)

            case .externalVideos:
                externalPlacesSheet

            case .reviews:
                reviewsSheet

            case .favorites:
                favoritesSheet

            case .myPlaces:
                myPlacesSheet

            // Map Popups (External User Data)
            case .externalReviews:
                externalReviewsSheet

            case .externalList(let listId):
                externalListSheet(listId: listId)

            case .externalFavorites:
                externalFavoritesSheet

            // Search Results
            case .keywordResults(let keyword, let types):
                keywordResultsSheet(keyword: keyword, types: types)

            // Nearby Discovery
            case .nearbyDiscovery:
                nearbyDiscoverySheet

            // City Overview
            case .cityOverview(let cityName, let coordinate, let annotation):
                cityOverviewSheet(cityName: cityName, coordinate: coordinate, annotation: annotation)

            // Onboarding
            case .suggestedProfiles:
                suggestedProfilesSheet
            }
        }
    }

    // MARK: - Individual Sheet Builders

    /// Place detail sheet content.
    private var placeDetailSheet: some View {
        PlaceDetailView(minSheetHeight: searchCoordinator.minSheetHeight)
            .environmentObject(selectedPlaceVM)
            .environmentObject(locationManager)
            .environmentObject(userSession)
            .environmentObject(userProfileNavigationViewModel)
            .environmentObject(notificationManager)
            .environmentObject(profileViewModel)
            .environmentObject(detailPlaceViewModel)
            .environmentObject(serviceContainer)
            .environmentObject(dataManager)
            .presentationDetents([.height(searchCoordinator.minSheetHeight), .height(800)])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.clear)
            .presentationBackgroundInteraction(.enabled(upThrough: .height(800)))
            .interactiveDismissDisabled(false)
    }

    /// External place selection sheet content.
    private var externalPlaceSelectionSheet: some View {
        ExternalPlaceSelectionView()
            .environmentObject(profileViewModel)
            .environmentObject(selectedPlaceVM)
            .environmentObject(detailPlaceViewModel)
            .environmentObject(dataManager)
            .environmentObject(userSession)
            .presentationDragIndicator(.visible)
    }

    /// No places found sheet content.
    private func noPlacesFoundSheet(contentUrl: String) -> some View {
        NoPlacesFoundView(contentUrl: contentUrl)
            .environmentObject(profileViewModel)
            .environmentObject(selectedPlaceVM)
            .environmentObject(userSession)
            .environmentObject(detailPlaceViewModel)
            .presentationDragIndicator(.visible)
    }

    /// Import place confirmation sheet content.
    private func importPlaceConfirmationSheet(placeId: String, contentUrl: String) -> some View {
        Group {
            if let place = detailPlaceViewModel.places[placeId] {
                ImportPlaceConfirmationView(place: place, contentUrl: contentUrl)
                    .environmentObject(profileViewModel)
                    .environmentObject(selectedPlaceVM)
                    .environmentObject(detailPlaceViewModel)
                    .presentationDetents([.height(340)])
            } else {
                VStack {
                    ProgressView()
                        .padding()
                    Text("Loading place...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    /// User's list popup sheet content.
    private func listSheet(listId: String) -> some View {
        Group {
            if let listIndex = profileViewModel.listsViewModel.lightweightPlaceLists.firstIndex(where: { $0.id == listId }) {
                LightweightListPopupView(
                    lists: profileViewModel.listsViewModel.lightweightPlaceLists,
                    initialListIndex: listIndex,
                    listsVM: profileViewModel.listsViewModel,
                    reviewsVM: profileViewModel.reviewsViewModel
                )
                .id(listId)
            } else {
                loadingListView
            }
        }
        .applyMapPopupEnvironment(from: self)
        .applyMapPopupPresentation()
        .onDisappear { handleMapPopupDisappear() }
    }

    /// External places popup sheet content.
    private var externalPlacesSheet: some View {
        ExternalPlacesPopupView(externalContentVM: profileViewModel.externalContentViewModel)
            .applyMapPopupEnvironment(from: self)
            .applyMapPopupPresentation()
            .onDisappear { handleMapPopupDisappear() }
    }

    /// Reviews popup sheet content.
    private var reviewsSheet: some View {
        ReviewsListPopupView(reviewsVM: profileViewModel.reviewsViewModel)
            .applyMapPopupEnvironment(from: self)
            .applyMapPopupPresentation()
            .onDisappear { handleMapPopupDisappear() }
    }

    /// Favorites popup sheet content.
    private var favoritesSheet: some View {
        FavoritesPopupView(favoritesVM: profileViewModel.favoritesViewModel)
            .applyMapPopupEnvironment(from: self)
            .applyMapPopupPresentation()
            .onDisappear { handleMapPopupDisappear() }
    }

    /// My places popup sheet content.
    private var myPlacesSheet: some View {
        MyPlacesListView(myPlacesVM: profileViewModel.myPlacesViewModel)
            .applyMapPopupEnvironment(from: self)
            .applyMapPopupPresentation()
            .onDisappear { handleMapPopupDisappear() }
    }

    /// External reviews popup sheet content.
    private var externalReviewsSheet: some View {
        ExternalReviewsListPopupView(
            mapDisplayCoordinatorVM: mapDisplayCoordinatorViewModel
        )
        .applyMapPopupEnvironment(from: self)
        .applyMapPopupPresentation()
        .onDisappear { handleMapPopupDisappear() }
    }

    /// External list popup sheet content.
    private func externalListSheet(listId: String) -> some View {
        Group {
            if let listIndex = mapDisplayCoordinatorViewModel.mapDisplayLists.firstIndex(where: { $0.list_id == listId }) {
                ExternalUserLightweightListPopupView(
                    viewModel: ExternalListPopupViewModel(
                        lists: mapDisplayCoordinatorViewModel.mapDisplayLists,
                        initialListIndex: listIndex,
                        preloadedPlaces: mapDisplayCoordinatorViewModel.mapDisplayListPlaces
                    ),
                    showBackToProfileButton: true
                )
            } else {
                loadingListView
            }
        }
        .applyMapPopupEnvironment(from: self)
        .applyMapPopupPresentation()
        .onDisappear { handleMapPopupDisappear() }
    }

    /// External favorites popup sheet content.
    private var externalFavoritesSheet: some View {
        ExternalFavoritesListPopupView(
            mapDisplayCoordinatorVM: mapDisplayCoordinatorViewModel
        )
        .applyMapPopupEnvironment(from: self)
        .applyMapPopupPresentation()
        .onDisappear { handleMapPopupDisappear() }
    }

    /// Nearby discovery popup sheet content.
    private var nearbyDiscoverySheet: some View {
        NearbyDiscoverySheet()
            .applyMapPopupEnvironment(from: self)
            .applyMapPopupPresentation()
    }

    /// City overview sheet showing lists, top places, and active users for a city.
    private func cityOverviewSheet(cityName: String, coordinate: CLLocationCoordinate2D, annotation: CityAnnotation?) -> some View {
        CityDetailSheet(cityName: cityName, coordinate: coordinate, annotation: annotation)
            .environmentObject(profileViewModel)
            .environmentObject(userSession)
            .environmentObject(userProfileNavigationViewModel)
            .environmentObject(selectedPlaceVM)
            .environmentObject(detailPlaceViewModel)
            .environmentObject(locationManager)
            .environmentObject(mapDisplayCoordinatorViewModel)
            .environmentObject(dataManager)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled(upThrough: .large))
    }

    /// Keyword results popup sheet content.
    private func keywordResultsSheet(keyword: String, types: [String]) -> some View {
        KeywordResultsPopupView(keyword: keyword, types: types)
            .applyMapPopupEnvironment(from: self)
            .applyMapPopupPresentation()
            .onDisappear { handleMapPopupDisappear() }
    }

    /// Suggested profiles popup sheet content.
    private var suggestedProfilesSheet: some View {
        SuggestedProfilesPopupView(
            isPresented: Binding(
                get: { PresentationService.shared.activeSheet == .suggestedProfiles },
                set: { if !$0 { PresentationService.shared.dismiss() } }
            )
        )
        .environmentObject(profileViewModel)
        .environmentObject(detailPlaceViewModel)
        .environmentObject(userSession)
        .environmentObject(selectedPlaceVM)
        .environmentObject(userProfileNavigationViewModel)
        .environmentObject(mapDisplayCoordinatorViewModel)
        .environmentObject(locationManager)
        .environmentObject(dataManager)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    /// Loading view for lists.
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

    /// Handles cleanup when a map popup sheet disappears.
    /// Only clears state if the sheet is actually dismissed (not during view hierarchy transitions).
    private func handleMapPopupDisappear() {
        // Only clear state if the sheet is actually dismissed (activeSheet is nil)
        // This prevents clearing state during fullScreenCover transitions
        guard presentationService.activeSheet == nil else { return }
        profileViewModel.selectedListIdForMap = nil
        profileViewModel.pendingMapFilter = nil
        profileViewModel.externalContentViewModel.disableNearbyFilter()
        // Note: Map filter clearing is now handled by MapContainerView's onChange of activeSheet
    }

    // MARK: - UI Overlay Layer
    private var uiOverlayLayer: some View {
        VStack {
            HStack {
                Spacer()
                VStack(spacing: 10) {
                    Button(action: { recenterMap = true }) {
                        Image(systemName: "location.fill")
                            .foregroundColor(.secondary)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                            .shadow(radius: 4)
                    }

                    Menu {
                        Picker("Display", selection: $annotationDisplayMode) {
                            ForEach(AnnotationDisplayMode.allCases, id: \.self) { mode in
                                Label(mode.label, systemImage: mode.iconName).tag(mode)
                            }
                        }
                    } label: {
                        Image(systemName: annotationDisplayMode.iconName)
                            .foregroundColor(.secondary)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                            .shadow(radius: 4)
                    }

                    Button(action: {
                        isSatelliteMap.toggle()
                    }) {
                        Image(systemName: isSatelliteMap ? "globe.americas.fill" : "globe.americas")
                            .foregroundColor(.secondary)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                            .shadow(radius: 4)
                    }
                }
                .padding(.top, 10)
                .padding(.trailing, 20)
            }

            Spacer()
        }
        .overlay(bottomNavigationBar)
        .sheet(isPresented: $showSearchPage, onDismiss: {
            if appCoordinator.hasPendingKeywordPopup {
                appCoordinator.hasPendingKeywordPopup = false
                DispatchQueue.main.async {
                    appCoordinator.showKeywordResultsPopup = true
                }
            }
            if let coordinate = appCoordinator.coordinateForPlaceCreation {
                appCoordinator.coordinateForPlaceCreation = nil
                withAnimation(.easeOut(duration: 0.25)) {
                    mapPosition = .region(MKCoordinateRegion(
                        center: coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    ))
                }
                // After map settles, drop pin and show place detail
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    selectedPlaceVM.selectDroppedPin(at: coordinate)
                }
            }
        }) {
            searchPageView
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .interactiveDismissDisabled()
        }
    }

    // MARK: - Bottom Navigation Bar
    /// Single Responsibility: Conditionally display bottom navigation bar based on UI state.
    private var bottomNavigationBar: some View {
        Group {
            if shouldShowBottomNavigationBar {
                VStack {
                    Spacer()
                    BottomNavigationBar(
                        showSearchPage: $showSearchPage,
                        shouldNavigateToProfile: $shouldNavigateToProfile,
                        shouldNavigateToFeed: $shouldNavigateToFeed,
                        showTripsSheet: $showTripsSheet
                    )
                    .environmentObject(profileViewModel)
                }
            }
        }
    }

    /// Determines if bottom navigation bar should be visible.
    private var shouldShowBottomNavigationBar: Bool {
        presentationService.activeSheet == nil &&
        !isCreatePlacePopupActive
    }

    // MARK: - Search Page

    /// Builds the search page view with proper ViewModel and callbacks.
    private var searchPageView: some View {
        SearchPageViewWrapper(
            searchViewModel: searchViewModel,
            searchCoordinator: searchCoordinator,
            showSearchPage: $showSearchPage
        )
        .environmentObject(userProfileNavigationViewModel)
        .environmentObject(profileViewModel)
        .environmentObject(selectedPlaceVM)
        .environmentObject(detailPlaceViewModel)
        .environmentObject(userSession)
        .environmentObject(mapDisplayCoordinatorViewModel)
        .environmentObject(locationManager)
        .environmentObject(dataManager)
        .environmentObject(appCoordinator)
    }

    // MARK: - Loading Overlay
    private var loadingOverlay: some View {
        Group {
            if deepLinkViewModel.isProcessingDeepLink ||
               externalContentVM.isProcessingContent ||
               externalContentVM.isWaitingForPlaceDetail {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    if externalContentVM.importError != nil {
                        errorView
                    } else {
                        loadingView
                    }
                }
            }
        }
    }

    // MARK: - Helper Views
    private var errorView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)

            Text("Import Failed")
                .font(.headline)
                .foregroundColor(.white)

            Text(externalContentVM.importError ?? "Unknown error")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("Try Again") {
                externalContentVM.clearImportError()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .background(Color.orange)
            .foregroundColor(.white)
            .cornerRadius(8)
            .font(.headline)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: .white))

            Text("Processing Video...")
                .font(.headline)
                .foregroundColor(.white)

            Text("Extracting place information")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
        }
    }

}

// MARK: - View Extensions for Map Popup Sheets

extension View {
    /// Applies common presentation settings for map popup sheets.
    func applyMapPopupPresentation() -> some View {
        self
            .presentationDetents([.height(300), .height(800)])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.clear)
            .presentationBackgroundInteraction(.enabled(upThrough: .height(800)))
    }
}

// MARK: - Map Popup Environment Modifier

/// ViewModifier that injects environment objects needed by map popup sheets.
/// Cleaner than passing `self` to an extension method.
struct MapPopupEnvironmentModifier: ViewModifier {
    let profile: ProfileViewModel
    let selectedPlace: SelectedPlaceViewModel
    let detailPlace: DetailPlaceViewModel
    let dataManager: DataManager
    let userProfileNavigation: UserProfileNavigationViewModel
    let mapDisplayCoordinator: MapDisplayCoordinatorViewModel
    let serviceContainer: ServiceContainer
    let notificationManager: NotificationManager

    func body(content: Content) -> some View {
        content
            .environmentObject(profile)
            .environmentObject(selectedPlace)
            .environmentObject(detailPlace)
            .environmentObject(dataManager)
            .environmentObject(userProfileNavigation)
            .environmentObject(mapDisplayCoordinator)
            .environmentObject(serviceContainer)
            .environmentObject(notificationManager)
    }
}

extension MainView {
    /// Creates a modifier that injects map popup environment objects from this MainView.
    func mapPopupEnvironmentModifier() -> MapPopupEnvironmentModifier {
        MapPopupEnvironmentModifier(
            profile: profileViewModel,
            selectedPlace: selectedPlaceVM,
            detailPlace: detailPlaceViewModel,
            dataManager: dataManager,
            userProfileNavigation: userProfileNavigationViewModel,
            mapDisplayCoordinator: mapDisplayCoordinatorViewModel,
            serviceContainer: serviceContainer,
            notificationManager: notificationManager
        )
    }
}

extension View {
    /// Applies map popup environment objects. Called from MainView context.
    func applyMapPopupEnvironment(from mainView: MainView) -> some View {
        self.modifier(mainView.mapPopupEnvironmentModifier())
    }
}
