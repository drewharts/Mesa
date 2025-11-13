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
    
    let deepLinkManager: DeepLinkManager
    let dataManager: DataManager
    let serviceContainer: ServiceContainer
    
    // MARK: - Local UI State
    @State private var sheetHeight: CGFloat = 250
    @State private var minSheetHeight: CGFloat = 250
    @State private var maxSheetHeight: CGFloat = UIScreen.main.bounds.height * 0.85
    @State private var shouldNavigateToProfile = false
    @State private var recenterMap = false
    @State private var isCreatePlacePopupActive = false
    @State private var mapPosition = MapCameraPosition.automatic
    
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
                
                uiOverlayLayer
                loadingOverlay
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $profileViewModel.isShowingPlaceSelection) {
                TikTokPlaceSelectionView()
                    .environmentObject(profileViewModel)
                    .environmentObject(selectedPlaceVM)
                    .environmentObject(detailPlaceViewModel)
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
            .sheet(isPresented: $userProfileViewModel.isUserDetailPresented) {
                UserProfileView(
                    userId: userSession.currentUserId ?? "",
                    UserProfileVM: userProfileViewModel
                )
                .environmentObject(profileViewModel)
                .environmentObject(selectedPlaceVM)
                .environmentObject(detailPlaceViewModel)
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
        VStack(spacing: 0) {
            topControls
            Spacer(minLength: 0)
            PlaceDetailContainerView(
                profileViewModel: profileViewModel,
                detailPlaceViewModel: detailPlaceViewModel,
                serviceContainer: serviceContainer,
                sheetHeight: $sheetHeight,
                minSheetHeight: minSheetHeight,
                maxSheetHeight: maxSheetHeight
            )
            .environmentObject(selectedPlaceVM)
            .environmentObject(userProfileViewModel)
            .environmentObject(notificationManager)
            .environmentObject(appCoordinator)
        }
        .overlay(floatingActionButtons)
    }
    
    // MARK: - Top Controls
    private var topControls: some View {
        Group {
            if appCoordinator.isSearchExpanded {
                SearchContainerView(
                    isSearchExpanded: $appCoordinator.isSearchExpanded,
                    placeService: serviceContainer.placeService,
                    userService: serviceContainer.userService,
                    locationManager: locationManager,
                    selectedPlaceViewModel: selectedPlaceVM,
                    onPlaceSelected: {
                        // Place selection is handled by SearchViewModel
                    },
                    onUserSelected: { profileData in
                        guard let currentUserId = userSession.currentUserId else { return }
                        userProfileViewModel.selectUser(profileData, currentUserId: currentUserId)
                    }
                )
            } else {
                minimizedControls
            }
        }
    }
    
    // MARK: - Minimized Controls
    private var minimizedControls: some View {
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
    }
    
    // MARK: - Floating Action Buttons
    private var floatingActionButtons: some View {
        Group {
            if !appCoordinator.isSearchExpanded && 
               !selectedPlaceVM.isDetailSheetPresented && 
               !isCreatePlacePopupActive {
                FloatingActionButtons(
                    isSearchBarMinimized: Binding(
                        get: { !appCoordinator.isSearchExpanded },
                        set: { appCoordinator.isSearchExpanded = !$0 }
                    ),
                    searchIsFocused: .constant(false),
                    sheetHeight: $sheetHeight,
                    shouldNavigateToProfile: $shouldNavigateToProfile,
                    maxSheetHeight: maxSheetHeight,
                    minSheetHeight: minSheetHeight
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
