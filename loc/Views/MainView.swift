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
    
    // MARK: - Required ViewModels (passed from parent as @ObservedObject)
    @ObservedObject var selectedPlaceVM: SelectedPlaceViewModel
    @ObservedObject var profileViewModel: ProfileViewModel
    @ObservedObject var userProfileNavigationViewModel: UserProfileNavigationViewModel
    @ObservedObject var mapDisplayCoordinatorViewModel: MapDisplayCoordinatorViewModel
    @ObservedObject var detailPlaceViewModel: DetailPlaceViewModel
    @ObservedObject var deepLinkViewModel: DeepLinkViewModel
    @ObservedObject var notificationManager: NotificationManager
    
    // MARK: - Pass-through ViewModels (no observation to prevent render loops)
    let searchViewModel: SearchViewModel  // ✅ Pass-through only, no observation
    let searchCoordinator: SearchCoordinatorViewModel  // ✅ Coordinator (no observation)
    
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
            .sheet(isPresented: Binding(
                get: { tikTokVM.isShowingPlaceSelection },
                set: { tikTokVM.isShowingPlaceSelection = $0 }
            )) {
                TikTokPlaceSelectionView()
                    .environmentObject(profileViewModel)
                    .environmentObject(selectedPlaceVM)
                    .environmentObject(detailPlaceViewModel)
                    .environmentObject(dataManager)
                    .environmentObject(userSession)
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: Binding(
                get: { tikTokVM.isShowingNoPlacesFound },
                set: { tikTokVM.isShowingNoPlacesFound = $0 }
            )) {
                TikTokNoPlacesFoundView(tikTokUrl: tikTokVM.noPlacesFoundTikTokUrl)
                    .environmentObject(profileViewModel)
                    .environmentObject(userSession)
                    .environmentObject(detailPlaceViewModel)
                    .presentationDragIndicator(.visible)
            }
            // Native SwiftUI sheet for place detail (replaces custom BottomSheetView)
            // Single Responsibility: Present place detail sheet using native iOS sheet behavior
            // MVVM: Uses ViewModel state to control presentation
            .sheet(isPresented: $selectedPlaceVM.isDetailSheetPresented) {
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
            .onChange(of: userProfileNavigationViewModel.isUserDetailPresented) { oldValue, newValue in
                // Dismiss PlaceDetailView sheet when navigating to user profile
                // MVVM: View observes ViewModel state changes and coordinates sheet dismissal
                if newValue && selectedPlaceVM.isDetailSheetPresented {
                    // Preserve state if navigating from place detail context
                    if userProfileNavigationViewModel.navigatedFromPlaceDetail {
                        selectedPlaceVM.preserveStateForNavigation()
                    }
                    selectedPlaceVM.isDetailSheetPresented = false
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
    /// Single Responsibility: Conditionally display floating action buttons based on UI state
    /// MVVM: Uses ViewModel state to determine visibility (no business logic)
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
    
    /// Single Responsibility: Determines if floating action buttons should be visible
    /// MVVM: Pure function that checks ViewModel state - no side effects
    private var shouldShowFloatingActionButtons: Bool {
        !selectedPlaceVM.isDetailSheetPresented &&
        !isCreatePlacePopupActive &&
        profileViewModel.selectedListIdForMap == nil // Hide when list popup is showing
    }

    // MARK: - Search Page

    /// Builds the search page view with proper ViewModel and callbacks
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

    /// Handle map tap - no-op since search is now fullScreenCover
    private func handleMapTap() {
        // Search is now presented as fullScreenCover, no need to collapse
    }
}
