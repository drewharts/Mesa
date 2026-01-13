//
//  PlaceDetailViewInNavigation.swift
//  loc
//
//  Created by Assistant on navigation integration
//
//  Wrapper view for PlaceDetailView when used in NavigationStack
//  Single Responsibility: Load place details and present PlaceDetailView without NavigationView wrapper
//  MVVM: Coordinates between SelectedPlaceViewModel and PlaceDetailView

import SwiftUI

struct PlaceDetailViewInNavigation: View {
    let placeId: String
    let minSheetHeight: CGFloat
    
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var serviceContainer: ServiceContainer
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    
    @State private var isLoading = true
    @State private var loadError: Error?
    @State private var originalAllowAutoPresent: Bool = true // Store original value to restore later
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading place details...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = loadError {
                VStack(spacing: 16) {
                    Text("Error loading place")
                        .font(.headline)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                // PlaceDetailView without NavigationView wrapper (we're already in NavigationStack)
                PlaceDetailViewContent(minSheetHeight: minSheetHeight)
                    .environmentObject(selectedPlaceVM)
                    .environmentObject(profile)
                    .environmentObject(locationManager)
                    .environmentObject(userProfileViewModel)
                    .environmentObject(userSession)
                    .environmentObject(serviceContainer)
                    .environmentObject(dataManager)
                    .environmentObject(detailPlaceViewModel)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadPlace()
        }
        .onDisappear {
            // Restore allowAutoPresent when leaving this view
            // MVVM: Clean up state when view is dismissed
            selectedPlaceVM.allowAutoPresent = originalAllowAutoPresent

            // Clear selected place to remove beacon when navigating back to list
            selectedPlaceVM.selectedPlace = nil
        }
    }
    
    /// Loads place details and sets up SelectedPlaceViewModel
    /// MVVM: Business logic - coordinates place loading
    /// Staff Engineer: Prevents auto-presentation of sheet when navigating within NavigationStack
    private func loadPlace() async {
        do {
            // Fetch the full place details using PlaceService
            let fullPlace = try await PlaceService.shared.fetchPlace(withId: placeId)
            
            // Set up place in SelectedPlaceViewModel WITHOUT triggering sheet presentation
            // MVVM: We're in NavigationStack, so we don't want to trigger the sheet in MainView
            await MainActor.run {
                // Disable auto-present to prevent sheet from showing in MainView
                // Keep it disabled - loadData() runs asynchronously and will check this
                // We'll restore it in onDisappear when this view is dismissed
                originalAllowAutoPresent = selectedPlaceVM.allowAutoPresent
                selectedPlaceVM.allowAutoPresent = false
                
                // Set up place (this will load data but won't auto-present sheet)
                // Animate map to place location when navigating from list popup
                selectedPlaceVM.selectPlaceAndFetchDetails(fullPlace, shouldAnimateMap: true)
                
                // Ensure sheet is NOT presented (we're using NavigationStack)
                selectedPlaceVM.isDetailSheetPresented = false
                
                isLoading = false
            }
        } catch {
            await MainActor.run {
                loadError = error
                isLoading = false
            }
            print("❌ [PlaceDetailViewInNavigation] Error loading place details: \(error)")
        }
    }
}

/// Content view extracted from PlaceDetailView to work without NavigationView wrapper
/// Single Responsibility: Display place detail content (reusable in both sheet and navigation contexts)
struct PlaceDetailViewContent: View {
    let minSheetHeight: CGFloat
    
    @State private var selectedImageIndex: Int?
    @State private var showPhotoGallery = false
    @State private var galleryPhotos: [UIImage] = []
    @State private var showNoPhoneNumberAlert = false
    @State private var showListSelection = false
    @State private var showCreatePost = false
    @State private var listSelectionViewModel: PlaceListSelectionViewModel?
    
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var serviceContainer: ServiceContainer
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    
    @State private var tabsViewModel: PlaceDetailTabsViewModel?
    
    var body: some View {
        ZStack {
            VStack(spacing: 16) {
                if selectedPlaceVM.selectedPlace == nil {
                    ProgressView("Loading Place Details...")
                } else if let tabsViewModel = tabsViewModel {
                    PlaceDetailTabsView(
                        viewModel: tabsViewModel,
                        showNoPhoneNumberAlert: $showNoPhoneNumberAlert,
                        onPhotoTapped: { photos, index in
                            galleryPhotos = photos
                            selectedImageIndex = index
                            showPhotoGallery = true
                        },
                        onAddToList: { showListSelection = true },
                        onAddReview: { showCreatePost = true }
                    )
                    .environmentObject(userProfileViewModel)
                    .environmentObject(detailPlaceViewModel)
                }
            }
            .frame(maxWidth: .infinity)
            .ignoresSafeArea(edges: [.bottom, .horizontal])
            .onAppear {
                // Initialize the ViewModel when the view appears
                if tabsViewModel == nil {
                    tabsViewModel = PlaceDetailTabsViewModel(
                        placeService: serviceContainer.placeService,
                        postService: serviceContainer.postService,
                        userService: serviceContainer.userService,
                        notificationManager: serviceContainer.notificationManager,
                        placeShareService: serviceContainer.placeShareService,
                        selectedPlaceVM: selectedPlaceVM,
                        profileVM: profile,
                        userSession: userSession,
                        detailPlaceViewModel: detailPlaceViewModel
                    )
                    
                    // Configure savers VM for navigation
                    tabsViewModel?.configureSaversViewModel(userProfileViewModel: userProfileViewModel)
                    
                    // Calculate travel time now that ViewModel is created
                    if let place = selectedPlaceVM.selectedPlace,
                       let currentLocation = locationManager.currentLocation {
                        tabsViewModel?.travelTimeViewModel.updateTravelTime(for: place, from: currentLocation.coordinate)
                    }
                }
            }
            .alert(isPresented: $showNoPhoneNumberAlert) {
                Alert(
                    title: Text("Phone Number Not Available"),
                    message: Text("No phone number is available for this place."),
                    dismissButton: .default(Text("OK"))
                )
            }
            .sheet(isPresented: $showListSelection) {
                if let selectedPlace = selectedPlaceVM.selectedPlace,
                   let viewModel = listSelectionViewModel {
                    ListSelectionSheet(
                        viewModel: viewModel,
                        place: selectedPlace,
                        isPresented: $showListSelection
                    )
                    .onDisappear {
                        listSelectionViewModel = nil
                    }
                } else {
                    Text("No place selected")
                }
            }
            .onChange(of: showListSelection) { oldValue, newValue in
                if newValue && listSelectionViewModel == nil {
                    listSelectionViewModel = PlaceListSelectionViewModel(
                        profile: profile,
                        userSession: userSession
                    )
                }
            }
            .sheet(isPresented: $showCreatePost) {
                if let selectedPlace = selectedPlaceVM.selectedPlace {
                    CreatePostView(
                        place: selectedPlace,
                        userId: userSession.currentUserId ?? "",
                        profilePhotoUrl: profile.user?.profilePhotoURL?.absoluteString ?? "",
                        userFirstName: profile.user?.firstName ?? "",
                        userLastName: profile.user?.lastName ?? ""
                    )
                    .environmentObject(selectedPlaceVM)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                } else {
                    Text("No place selected")
                }
            }
            .onAppear {
                if let place = selectedPlaceVM.selectedPlace,
                   let currentLocation = locationManager.currentLocation,
                   let tabsVM = tabsViewModel {
                    tabsVM.travelTimeViewModel.updateTravelTime(for: place, from: currentLocation.coordinate)
                }
                
                // Refresh TikTok places when place detail view appears
                profile.refreshTikTokPlacesAfterImport()
            }
            .onChange(of: selectedPlaceVM.selectedPlace) { _, newPlace in
                if let place = newPlace,
                   let currentLocation = locationManager.currentLocation?.coordinate,
                   let tabsVM = tabsViewModel {
                    tabsVM.travelTimeViewModel.updateTravelTime(for: place, from: currentLocation)
                }
            }
            
            // Photo Gallery Overlay (Pinterest-style) - fills entire sheet
            if showPhotoGallery, let selectedIndex = selectedImageIndex {
                PinterestPhotoGalleryView(
                    photos: galleryPhotos,
                    initialIndex: selectedIndex,
                    isPresented: $showPhotoGallery
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
                .zIndex(100)
            }
        }
    }
}
