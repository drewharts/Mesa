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
    @State private var showCreateReview = false

    @EnvironmentObject var profile: ProfileViewModel

    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var serviceContainer: ServiceContainer
    @Environment(\.isScrollingEnabled) var isScrollingEnabled // Access scroll state

    @StateObject private var viewModel = PlaceDetailViewModel()

    init(sheetHeight: Binding<CGFloat>, minSheetHeight: CGFloat) {
        self._sheetHeight = sheetHeight
        self.minSheetHeight = minSheetHeight
    }

    var body: some View {
        ZStack {
            VStack(spacing: 16) {
                if viewModel.placeName == "Unknown" {
                    ProgressView("Loading Place Details...")
                } else {
                    MinPlaceDetailView(
                        viewModel: viewModel,
                        showNoPhoneNumberAlert: $showNoPhoneNumberAlert,
                        onPhotoTapped: { photos, index in
                            galleryPhotos = photos
                            selectedImageIndex = index
                            showPhotoGallery = true
                        }
                    )
                    .environmentObject(userProfileViewModel)
                    .scrollDisabled(!isScrollingEnabled) // Disable scrolling based on sheet height
                }
            }
            .padding(.vertical)
            .frame(maxWidth: .infinity)
            .blur(radius: showPhotoGallery ? 10 : 0)
            .alert(isPresented: $viewModel.showAlert) {
                Alert(title: Text("Success"),
                      message: Text(viewModel.alertMessage),
                      dismissButton: .default(Text("OK")))
            }
            .alert(isPresented: $showNoPhoneNumberAlert) {
                Alert(
                    title: Text("Phone Number Not Available"),
                    message: Text("No phone number is available for this place."),
                    dismissButton: .default(Text("OK"))
                )
            }
            .sheet(isPresented: $showListSelection) {
                if let selectedPlace = selectedPlaceVM.selectedPlace {
                    ListSelectionSheet(
                        place: selectedPlace,
                        isPresented: $showListSelection
                    )
                    .environmentObject(profile)
                    .environmentObject(viewModel)
                } else {
                    Text("No place selected")
                }
            }
            .sheet(isPresented: $showCreateReview) {
                if let selectedPlace = selectedPlaceVM.selectedPlace {
                    CreatePlaceReviewView(
                        isPresented: $showCreateReview,
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
                print("📱 [PlaceDetailView] View appeared, starting to load place data...")
                if let place = selectedPlaceVM.selectedPlace,
                   let currentLocation = locationManager.currentLocation {
                    viewModel.loadData(for: place, currentLocation: currentLocation.coordinate)
                }
            }
            .onChange(of: selectedPlaceVM.isCurrentPlaceFullyLoaded) { _, isLoaded in
                if isLoaded {
                    // Clear the waiting state when the place detail is fully loaded
                    print("✅ [PlaceDetailView] Place is fully loaded, calling placeDetailViewReady()")
                    profile.placeDetailViewReady()
                }
            }

            // Action button overlay - top right
            VStack {
                HStack {
                    Spacer()
                    if let place = selectedPlaceVM.selectedPlace {
                        PlaceActionButton(
                            place: place,
                            onAddToList: {
                                showListSelection = true
                            },
                            onAddReview: {
                                showCreateReview = true
                            }
                        )
                        .environmentObject(profile)
                        .environmentObject(userSession)
                        .environmentObject(serviceContainer)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                Spacer()
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

