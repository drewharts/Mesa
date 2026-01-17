//
//  RestaurantDetailView.swift (PlaceDetailView)
//  loc
//
//  Created by Andrew Hartsfield II on 11/8/24.
//

import SwiftUI

struct PlaceDetailView: View {
    let minSheetHeight: CGFloat

    @State private var selectedImageIndex: Int?
    @State private var showPhotoGallery = false
    @State private var galleryPhotos: [UIImage] = []
    @State private var galleryPresentationCount = 0
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

    // Removed PlaceDetailViewModel - travel time logic now in PlaceDetailTabsViewModel
    @State private var tabsViewModel: PlaceDetailTabsViewModel?

    init(minSheetHeight: CGFloat) {
        self.minSheetHeight = minSheetHeight
    }

    var body: some View {
        NavigationView {
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
                            galleryPresentationCount += 1
                            showPhotoGallery = true
                        },
                        onAddToList: { showListSelection = true },
                        onAddReview: { showCreatePost = true },
                        onPlaceChanged: { newPlaceId in
                            // Navigate to the new place after TikTok association change
                            selectedPlaceVM.navigateToPlace(placeId: newPlaceId)
                        }
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
            // Alert for travel time removed - no longer needed
            .alert(isPresented: $showNoPhoneNumberAlert) {
                Alert(
                    title: Text("Phone Number Not Available"),
                    message: Text("No phone number is available for this place."),
                    dismissButton: .default(Text("OK"))
                )
            }
            .sheet(isPresented: $showListSelection, onDismiss: {
                // Refresh list membership state after sheet closes
                tabsViewModel?.refreshPlaceListMembership()
                listSelectionViewModel = nil
            }) {
                if let selectedPlace = selectedPlaceVM.selectedPlace,
                   let viewModel = listSelectionViewModel {
                    ListSelectionSheet(
                        viewModel: viewModel,
                        place: selectedPlace,
                        isPresented: $showListSelection
                    )
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
                    // Backend creates external_place entry when selectPlaceAndFetchDetails is called
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
                .id(galleryPresentationCount) // Force fresh view on each presentation
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
                .zIndex(100)
            }
            }
            .navigationBarHidden(true)
        }
    }
}
