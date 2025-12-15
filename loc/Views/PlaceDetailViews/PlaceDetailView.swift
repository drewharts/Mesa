//
//  RestaurantDetailView.swift (PlaceDetailView)
//  loc
//
//  Created by Andrew Hartsfield II on 11/8/24.
//

import SwiftUI

struct PlaceDetailView: View {
    @Binding var sheetHeight: CGFloat
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
    @Environment(\.isScrollingEnabled) var isScrollingEnabled // Access scroll state

    // Removed PlaceDetailViewModel - travel time logic now in PlaceDetailTabsViewModel
    @State private var tabsViewModel: PlaceDetailTabsViewModel?

    init(sheetHeight: Binding<CGFloat>, minSheetHeight: CGFloat) {
        self._sheetHeight = sheetHeight
        self.minSheetHeight = minSheetHeight
    }

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
                    .scrollDisabled(!isScrollingEnabled)
                }
            }
            .padding(.vertical)
            .frame(maxWidth: .infinity)
            .blur(radius: showPhotoGallery ? 10 : 0)
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
                        isPresented: $showCreatePost,
                        place: selectedPlace,
                        userId: userSession.currentUserId ?? "",
                        profilePhotoUrl: profile.user?.profilePhotoURL?.absoluteString ?? "",
                        userFirstName: profile.user?.firstName ?? "",
                        userLastName: profile.user?.lastName ?? ""
                    )
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
            }
            .onChange(of: selectedPlaceVM.selectedPlace) { _, newPlace in
                if let place = newPlace,
                   let currentLocation = locationManager.currentLocation?.coordinate,
                   let tabsVM = tabsViewModel {
                    tabsVM.travelTimeViewModel.updateTravelTime(for: place, from: currentLocation)
                }
            }



            // Photo Gallery Overlay
            if showPhotoGallery, let selectedIndex = selectedImageIndex {
                PhotoGalleryView(
                    photos: galleryPhotos,
                    initialIndex: selectedIndex,
                    isPresented: $showPhotoGallery
                )
                .transition(.opacity)
                .animation(.easeInOut, value: showPhotoGallery)
            }
        }
    }
}

