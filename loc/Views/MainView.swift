//
//  MainView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/12/24.
//


import SwiftUI
import MapKit


struct MainView: View {
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var profileViewModel: ProfileViewModel
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var viewModel: SearchViewModel
    @EnvironmentObject var placeTypeFilterVM: PlaceTypeFilterViewModel
    @EnvironmentObject var deepLinkViewModel: DeepLinkViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel

    @FocusState private var searchIsFocused: Bool
    @State private var isSearchBarMinimized = true
    @State private var sheetHeight: CGFloat = 250
    @State private var minSheetHeight: CGFloat = 250
    @State private var maxSheetHeight: CGFloat = UIScreen.main.bounds.height * 0.85
    @State private var shouldNavigateToProfile = false
    @State private var triggerFocus = false
    @State private var recenterMap = false
    @State private var isCreatePlacePopupActive = false
    @State private var mapPosition = MapCameraPosition.automatic

    var body: some View {
        NavigationStack {
            ZStack {
                mapLayer
                uiOverlayLayer
                loadingOverlay
                noLocationAlert
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
            }
            // Present external user profiles
            .sheet(isPresented: $userProfileViewModel.isUserDetailPresented) {
                UserProfileView(
                    userId: userSession.currentUserId ?? "",
                    UserProfileVM: userProfileViewModel
                )
                .environmentObject(profileViewModel)
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
            viewModel.selectedPlaceVM = selectedPlaceVM
            viewModel.placeTypeFilterVM = placeTypeFilterVM
            viewModel.searchText = ""

            // Trigger immediate calculation of most frequent types
            placeTypeFilterVM.refreshMostFrequentTypes()

            // SearchViewModel is properly initialized
        }
        .onChange(of: selectedPlaceVM.isDetailSheetPresented) { _, newValue in
            if newValue {
                isSearchBarMinimized = true
                searchIsFocused = false
            }
        }
        .onChange(of: profileViewModel.userFavorites) {
            // Recalculate filters when user favorites change
            placeTypeFilterVM.refreshMostFrequentTypes()
        }
        .onChange(of: profileViewModel.userListsPlaces) {
            // Recalculate filters when user lists change
            placeTypeFilterVM.refreshMostFrequentTypes()
        }
        .onChange(of: selectedPlaceVM.shouldAnimateMapToPlace) { oldValue, newValue in
            if newValue, let place = selectedPlaceVM.selectedPlace, let coordinate = place.coordinate {
                // Animate map to place location with smooth animation
                withAnimation(.easeInOut(duration: 0.6)) {
                    mapPosition = .region(MKCoordinateRegion(
                        center: coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    ))
                }
                // Reset the flag after animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    selectedPlaceVM.shouldAnimateMapToPlace = false
                }
            }
        }
    }
    
    // MARK: - Map Layer
    private var mapLayer: some View {
        MapView(recenterMap: $recenterMap, mapPosition: $mapPosition, isSearchBarMinimized: isSearchBarMinimized, isCreatePlacePopupActive: $isCreatePlacePopupActive, onMapTap: {
            withAnimation {
                isSearchBarMinimized = true
                searchIsFocused = false
            }
        })
            .ignoresSafeArea()
            .edgesIgnoringSafeArea(.all)
    }
    
    // MARK: - UI Overlay Layer
    private var uiOverlayLayer: some View {
        VStack(spacing: 0) {
            topControls
            Spacer(minLength: 0)
            bottomSheet
        }
        .overlay(
            floatingActionButtons
        )
    }
    
    // MARK: - Top Controls
    private var topControls: some View {
        Group {
            if isSearchBarMinimized {
                minimizedControls
            } else {
                expandedSearchControls
            }
        }
    }
    
    // MARK: - Minimized Controls
    private var minimizedControls: some View {
        HStack {
            Spacer()
            VStack(spacing: 10) {
                Button(action: {
                    recenterMap = true
                }) {
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
            if isSearchBarMinimized && !searchIsFocused && !selectedPlaceVM.isDetailSheetPresented && !isCreatePlacePopupActive {
                FloatingActionButtons(
                    isSearchBarMinimized: $isSearchBarMinimized,
                    searchIsFocused: Binding(
                        get: { searchIsFocused },
                        set: { searchIsFocused = $0 }
                    ),
                    sheetHeight: $sheetHeight,
                    shouldNavigateToProfile: $shouldNavigateToProfile,
                    maxSheetHeight: maxSheetHeight,
                    minSheetHeight: minSheetHeight
                )
                .environmentObject(profileViewModel)
            }
        }
    }
    
    // MARK: - Expanded Search Controls  
    private var expandedSearchControls: some View {
        VStack(spacing: 16) {
            searchBar
            placeTypeFilterButtons
            searchResultsContainer
        }
    }
    
    // MARK: - Search Results Container
    private var searchResultsContainer: some View {
        Group {
            if !viewModel.searchResults.isEmpty || !viewModel.userResults.isEmpty || viewModel.showNoPlaceFound || viewModel.isSearching {
                SearchResultsView(
                    placeResults: viewModel.searchResults,
                    userResults: viewModel.userResults,
                    showNoPlaceFound: viewModel.showNoPlaceFound,
                    searchText: viewModel.searchText,
                    isSearching: viewModel.isSearching,
                    onSelectPlace: { prediction in
                        viewModel.selectSuggestion(prediction)
                        withAnimation {
                            isSearchBarMinimized = true
                            searchIsFocused = false
                        }
                    },
                    onSelectUser: { user in
                        guard let currentUserId = userSession.currentUserId else { return }
                        userProfileViewModel.selectUser(user, currentUserId: currentUserId)
                        withAnimation {
                            isSearchBarMinimized = true
                            searchIsFocused = false
                        }
                    }
                )
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 50)
            }
        }
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        TextField("Search here...", text: $viewModel.searchText)
            .padding()
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 3)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .foregroundStyle(Color.gray)
            .focused($searchIsFocused)
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, -10)
            .onTapGesture {
                searchIsFocused = true
            }
            // REMOVED: Duplicate onChange handler - SearchViewModel already handles this with debouncing
    }
    
    // MARK: - Place Type Filter Buttons
    private var placeTypeFilterButtons: some View {
        PlaceTypeFilterButtonsView(filterVM: placeTypeFilterVM)
            .padding(.horizontal, 20)
    }
    
    // MARK: - Bottom Sheet
    private var bottomSheet: some View {
        Group {
            if selectedPlaceVM.isDetailSheetPresented {
                BottomSheetView(
                    isPresented: $selectedPlaceVM.isDetailSheetPresented,
                    sheetHeight: $sheetHeight,
                    minSheetHeight: minSheetHeight,
                    maxSheetHeight: maxSheetHeight
                ) {
                    PlaceDetailView(
                        sheetHeight: $sheetHeight,
                        minSheetHeight: minSheetHeight
                    )
                    .environmentObject(userProfileViewModel)
                    .environmentObject(notificationManager)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
    
    // MARK: - Loading Overlay
    private var loadingOverlay: some View {
        Group {
            if deepLinkViewModel.isProcessingDeepLink || profileViewModel.isProcessingTikTok || profileViewModel.isWaitingForPlaceDetail {
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
    
    // MARK: - No Location Alert
    private var noLocationAlert: some View {
        EmptyView()
    }
    
    // MARK: - Error View
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
    
    // MARK: - Loading View
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
}
