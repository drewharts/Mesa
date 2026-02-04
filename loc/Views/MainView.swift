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
    @State private var showSearchPage = false
    @State private var recenterMap = false
    @State private var isCreatePlacePopupActive = false
    @State private var mapPosition = MapCameraPosition.automatic

    /// Convenience accessor for TikTok view model.
    private var tikTokVM: ProfileTikTokViewModel { profileViewModel.tikTokViewModel }

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
                    selectedPlaceViewModel: selectedPlaceVM,
                    detailPlaceViewModel: detailPlaceViewModel,
                    placeService: serviceContainer.placeService,
                    profileViewModel: profileViewModel,
                    dataManager: dataManager,
                    userProfileNavigationViewModel: userProfileNavigationViewModel,
                    mapDisplayCoordinatorViewModel: mapDisplayCoordinatorViewModel,
                    serviceContainer: serviceContainer,
                    notificationManager: notificationManager,
                    onMapTap: handleMapTap
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
                    presentationService.dismiss()
                }

                // Restore state when returning from profile (if navigated from place detail)
                if oldValue && !newValue && userProfileNavigationViewModel.navigatedFromPlaceDetail {
                    selectedPlaceVM.restoreStateAfterNavigation()
                    userProfileNavigationViewModel.navigatedFromPlaceDetail = false
                }
            }
            .fullScreenCover(isPresented: $shouldNavigateToProfile) {
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
            .fullScreenCover(isPresented: $showSearchPage) {
                searchPageView
            }
            .alert("No Location Found", isPresented: $deepLinkViewModel.showNoLocationAlert) {
                Button("OK") {
                    deepLinkViewModel.dismissNoLocationAlert()
                }
            } message: {
                Text(deepLinkViewModel.noLocationAlertMessage)
            }
        }
        .onAppear {
            locationManager.requestLocationPermission()
            // ViewModels now call PresentationService.shared directly - no wiring needed
        }
        .onChange(of: selectedPlaceVM.shouldAnimateMapToPlace) { _, newValue in
            if newValue, let place = selectedPlaceVM.selectedPlace, let coordinate = place.coordinate {
                withAnimation(.easeInOut(duration: 0.6)) {
                    mapPosition = .region(MKCoordinateRegion(
                        center: coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    ))
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    selectedPlaceVM.shouldAnimateMapToPlace = false
                }
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

            // TikTok Import
            case .tikTokPlaceSelection:
                tikTokPlaceSelectionSheet

            case .tikTokNoPlacesFound(let tikTokUrl):
                tikTokNoPlacesFoundSheet(tikTokUrl: tikTokUrl)

            // Map Popups (User's Own Data)
            case .list(let listId):
                listSheet(listId: listId)

            case .tiktoks:
                tiktoksSheet

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

    /// TikTok place selection sheet content.
    private var tikTokPlaceSelectionSheet: some View {
        TikTokPlaceSelectionView()
            .environmentObject(profileViewModel)
            .environmentObject(selectedPlaceVM)
            .environmentObject(detailPlaceViewModel)
            .environmentObject(dataManager)
            .environmentObject(userSession)
            .presentationDragIndicator(.visible)
    }

    /// TikTok no places found sheet content.
    private func tikTokNoPlacesFoundSheet(tikTokUrl: String) -> some View {
        TikTokNoPlacesFoundView(tikTokUrl: tikTokUrl)
            .environmentObject(profileViewModel)
            .environmentObject(userSession)
            .environmentObject(detailPlaceViewModel)
            .presentationDragIndicator(.visible)
    }

    /// User's list popup sheet content.
    private func listSheet(listId: String) -> some View {
        Group {
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
        .applyMapPopupEnvironment(from: self)
        .applyMapPopupPresentation()
        .onDisappear { handleMapPopupDisappear() }
    }

    /// TikToks popup sheet content.
    private var tiktoksSheet: some View {
        TikToksPopupView()
            .applyMapPopupEnvironment(from: self)
            .applyMapPopupPresentation()
            .onDisappear { handleMapPopupDisappear() }
    }

    /// Reviews popup sheet content.
    private var reviewsSheet: some View {
        ReviewsListPopupView()
            .applyMapPopupEnvironment(from: self)
            .applyMapPopupPresentation()
            .onDisappear { handleMapPopupDisappear() }
    }

    /// Favorites popup sheet content.
    private var favoritesSheet: some View {
        FavoritesPopupView()
            .applyMapPopupEnvironment(from: self)
            .applyMapPopupPresentation()
            .onDisappear { handleMapPopupDisappear() }
    }

    /// My places popup sheet content.
    private var myPlacesSheet: some View {
        MyPlacesListView()
            .applyMapPopupEnvironment(from: self)
            .applyMapPopupPresentation()
            .onDisappear { handleMapPopupDisappear() }
    }

    /// External reviews popup sheet content.
    private var externalReviewsSheet: some View {
        ExternalReviewsListPopupView(
            mapDisplayCoordinatorVM: mapDisplayCoordinatorViewModel,
            userProfileNavigationVM: userProfileNavigationViewModel
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
            mapDisplayCoordinatorVM: mapDisplayCoordinatorViewModel,
            userProfileNavigationVM: userProfileNavigationViewModel
        )
        .applyMapPopupEnvironment(from: self)
        .applyMapPopupPresentation()
        .onDisappear { handleMapPopupDisappear() }
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
                    .padding(.top, 10)
                    .padding(.trailing, 20)
                }
            }

            Spacer()
        }
        .overlay(floatingActionButtons)
    }

    // MARK: - Floating Action Buttons
    /// Single Responsibility: Conditionally display floating action buttons based on UI state.
    private var floatingActionButtons: some View {
        Group {
            if shouldShowFloatingActionButtons {
                FloatingActionButtons(
                    showSearchPage: $showSearchPage,
                    shouldNavigateToProfile: $shouldNavigateToProfile
                )
                .environmentObject(profileViewModel)
            }
        }
    }

    /// Determines if floating action buttons should be visible.
    private var shouldShowFloatingActionButtons: Bool {
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
               tikTokVM.isProcessingTikTok ||
               tikTokVM.isWaitingForPlaceDetail {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    if tikTokVM.tikTokImportError != nil {
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

            Text(tikTokVM.tikTokImportError ?? "Unknown error")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("Try Again") {
                tikTokVM.clearTikTokImportError()
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

            Text("Processing TikTok...")
                .font(.headline)
                .foregroundColor(.white)

            Text("Extracting place information")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
        }
    }

    // MARK: - Actions

    /// Handle map tap - no-op since search is now fullScreenCover.
    private func handleMapTap() {
        // Search is now presented as fullScreenCover, no need to collapse
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
