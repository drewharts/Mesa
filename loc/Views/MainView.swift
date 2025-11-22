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
    @ObservedObject var userProfileViewModel: UserProfileViewModel
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
    @State private var sheetHeight: CGFloat
    @State private var shouldNavigateToProfile = false
    @State private var recenterMap = false
    @State private var isCreatePlacePopupActive = false
    @State private var mapPosition = MapCameraPosition.automatic
    
    // MARK: - Initialization
    init(
        selectedPlaceVM: SelectedPlaceViewModel,
        profileViewModel: ProfileViewModel,
        userProfileViewModel: UserProfileViewModel,
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
        self.userProfileViewModel = userProfileViewModel
        self.detailPlaceViewModel = detailPlaceViewModel
        self.deepLinkViewModel = deepLinkViewModel
        self.notificationManager = notificationManager
        self.searchViewModel = searchViewModel
        self.searchCoordinator = searchCoordinator
        self.deepLinkManager = deepLinkManager
        self.dataManager = dataManager
        self.serviceContainer = serviceContainer
        
        // Initialize sheet height from coordinator
        self._sheetHeight = State(initialValue: searchCoordinator.maxSheetHeight)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Map Container - owns MapViewModel
                MapContainerView(
                    mapPosition: $mapPosition,
                    recenterMap: $recenterMap,
                    isSearchExpanded: $appCoordinator.isSearchExpanded,
                    isCreatePlacePopupActive: $isCreatePlacePopupActive,
                    selectedPlaceViewModel: selectedPlaceVM,
                    detailPlaceViewModel: detailPlaceViewModel,
                    placeService: serviceContainer.placeService,
                    profileViewModel: profileViewModel,
                    onMapTap: handleMapTap
                )
                
                // UI Overlay (Top Controls, FABs)
                uiOverlayLayer
                
                // Search Overlay (Isolated to prevent recreation)
                // Staff Engineer: Separate layer prevents TextField destruction on MainView re-renders
                SearchOverlayView(
                    searchViewModel: searchViewModel,
                    searchCoordinator: searchCoordinator,
                    onSheetHeightChange: { newHeight in
                        sheetHeight = newHeight
                    }
                )
                
                // Place Detail Sheet (Independent Z-Layer)
                // Moved out of VStack to prevent keyboard/layout constraints from affecting sheet height
                placeDetailLayer
                
                loadingOverlay
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $userProfileViewModel.isUserDetailPresented) {
                UserProfileView(
                    userId: userSession.currentUserId ?? "",
                    UserProfileVM: userProfileViewModel
                )
                .environmentObject(profileViewModel)
                .environmentObject(selectedPlaceVM)
                .environmentObject(detailPlaceViewModel)
            }
            .sheet(isPresented: $profileViewModel.isShowingPlaceSelection) {
                TikTokPlaceSelectionView()
                    .environmentObject(profileViewModel)
                    .environmentObject(selectedPlaceVM)
                    .environmentObject(detailPlaceViewModel)
                    .environmentObject(dataManager)
                    .environmentObject(userSession)
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $profileViewModel.isShowingNoPlacesFound) {
                TikTokNoPlacesFoundView(tikTokUrl: profileViewModel.noPlacesFoundTikTokUrl)
                    .environmentObject(profileViewModel)
                    .environmentObject(userSession)
                    .environmentObject(detailPlaceViewModel)
                    .presentationDragIndicator(.visible)
            }
            .fullScreenCover(isPresented: $shouldNavigateToProfile) {
                ProfileView()
                    .environmentObject(userProfileViewModel)
                    .environmentObject(deepLinkViewModel)
                    .environmentObject(selectedPlaceVM)
                    .environmentObject(detailPlaceViewModel)
                    .environmentObject(profileViewModel)
                    .environmentObject(deepLinkManager)
                    .environmentObject(dataManager)
                    .environmentObject(serviceContainer)
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
        .onChange(of: selectedPlaceVM.isDetailSheetPresented) { _, newValue in
            if newValue {
                appCoordinator.isSearchExpanded = false
                // Sheet height is set by SearchCoordinator when place selected
            } else {
                // Reset sheet height when dismissing so next open starts fresh
                sheetHeight = searchCoordinator.maxSheetHeight
            }
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
            .opacity(!appCoordinator.isSearchExpanded ? 1 : 0)
            .allowsHitTesting(!appCoordinator.isSearchExpanded)
            
            Spacer()
        }
        .overlay(floatingActionButtons)
    }
    
    // MARK: - Place Detail Layer
    // Isolated layer for the bottom sheet to ensure full-screen height availability
    private var placeDetailLayer: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            PlaceDetailContainerView(
                profileViewModel: profileViewModel,
                detailPlaceViewModel: detailPlaceViewModel,
                serviceContainer: serviceContainer,
                dataManager: dataManager,
                sheetHeight: $sheetHeight,
                minSheetHeight: searchCoordinator.minSheetHeight,
                maxSheetHeight: searchCoordinator.maxSheetHeight
            )
            .environmentObject(selectedPlaceVM)
            .environmentObject(userProfileViewModel)
            .environmentObject(notificationManager)
            .environmentObject(appCoordinator)
        }
    }
    
    // MARK: - Floating Action Buttons
    private var floatingActionButtons: some View {
        Group {
            if !appCoordinator.isSearchExpanded && 
               !selectedPlaceVM.isDetailSheetPresented && 
               !isCreatePlacePopupActive {
                FloatingActionButtons(
                    searchCoordinator: searchCoordinator,
                    isSearchBarMinimized: Binding(
                        get: { !appCoordinator.isSearchExpanded },
                        set: { appCoordinator.isSearchExpanded = !$0 }
                    ),
                    sheetHeight: $sheetHeight,
                    shouldNavigateToProfile: $shouldNavigateToProfile
                )
                .environmentObject(profileViewModel)
            }
        }
    }
    
    // MARK: - Loading Overlay
    private var loadingOverlay: some View {
        Group {
            if deepLinkViewModel.isProcessingDeepLink || 
               profileViewModel.isProcessingTikTok || 
               profileViewModel.isWaitingForPlaceDetail {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    if profileViewModel.tikTokImportError != nil {
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
            
            Text(profileViewModel.tikTokImportError ?? "Unknown error")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Try Again") {
                profileViewModel.clearTikTokImportError()
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
    private func handleMapTap() {
        withAnimation {
            appCoordinator.isSearchExpanded = false
        }
    }
}
