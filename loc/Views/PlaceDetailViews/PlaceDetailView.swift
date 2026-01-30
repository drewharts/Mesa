//
//  RestaurantDetailView.swift (PlaceDetailView)
//  loc
//
//  Created by Andrew Hartsfield II on 11/8/24.
//
//  Data-Driven: Drives ViewModel updates via .onChange() instead of ViewModel observing other ViewModels
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
    @State private var tabsViewModel: PlaceDetailTabsViewModel?

    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var userProfileNavigationViewModel: UserProfileNavigationViewModel
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel

    init(minSheetHeight: CGFloat) {
        self.minSheetHeight = minSheetHeight
    }

    var body: some View {
        NavigationView {
            ZStack {
                mainContent
                photoGalleryOverlay
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - Subviews

    /// The main content area containing loading state or tabs view.
    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 16) {
            if selectedPlaceVM.selectedPlace == nil {
                loadingView
            } else if let tabsViewModel = tabsViewModel {
                tabsContent(viewModel: tabsViewModel)
            }
        }
        .frame(maxWidth: .infinity)
        .ignoresSafeArea(edges: [.bottom, .horizontal])
        .onAppear(perform: handleAppear)
        .alert(isPresented: $showNoPhoneNumberAlert) {
            noPhoneNumberAlert
        }
        .sheet(isPresented: $showListSelection, onDismiss: handleListSelectionDismiss) {
            listSelectionSheetContent
        }
        .sheet(isPresented: $showCreatePost) {
            createPostSheetContent
        }
        .onChange(of: showListSelection) { _, newValue in
            handleListSelectionChanged(newValue)
        }
        .modifier(PlaceChangeHandler(
            tabsViewModel: $tabsViewModel,
            selectedPlaceVM: selectedPlaceVM,
            profile: profile,
            locationManager: locationManager
        ))
        .modifier(FavoritesChangeHandler(
            tabsViewModel: $tabsViewModel,
            selectedPlaceVM: selectedPlaceVM,
            profile: profile
        ))
        .modifier(TikTokChangeHandler(
            tabsViewModel: $tabsViewModel,
            selectedPlaceVM: selectedPlaceVM,
            profile: profile
        ))
    }

    /// Loading indicator shown while place data is being fetched.
    private var loadingView: some View {
        ProgressView("Loading Place Details...")
    }

    /// The place detail tabs view with all callbacks configured.
    @ViewBuilder
    private func tabsContent(viewModel: PlaceDetailTabsViewModel) -> some View {
        PlaceDetailTabsView(
            viewModel: viewModel,
            showNoPhoneNumberAlert: $showNoPhoneNumberAlert,
            onPhotoTapped: handlePhotoTapped,
            onAddToList: { showListSelection = true },
            onAddReview: { showCreatePost = true },
            onPlaceChanged: handlePlaceNavigation
        )
        .environmentObject(userProfileNavigationViewModel)
        .environmentObject(detailPlaceViewModel)
    }

    /// Photo gallery overlay shown when viewing photos in fullscreen.
    @ViewBuilder
    private var photoGalleryOverlay: some View {
        if showPhotoGallery, let selectedIndex = selectedImageIndex {
            PinterestPhotoGalleryView(
                photos: galleryPhotos,
                initialIndex: selectedIndex,
                isPresented: $showPhotoGallery
            )
            .id(galleryPresentationCount)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)
            .zIndex(100)
        }
    }

    // MARK: - Sheet Content

    /// Content for the list selection sheet.
    @ViewBuilder
    private var listSelectionSheetContent: some View {
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

    /// Content for the create post sheet.
    @ViewBuilder
    private var createPostSheetContent: some View {
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

    // MARK: - Alerts

    /// Alert shown when a place has no phone number.
    private var noPhoneNumberAlert: Alert {
        Alert(
            title: Text("Phone Number Not Available"),
            message: Text("No phone number is available for this place."),
            dismissButton: .default(Text("OK"))
        )
    }

    // MARK: - Event Handlers

    /// Handles view appearance - initializes ViewModel and refreshes TikTok data.
    private func handleAppear() {
        initializeViewModelIfNeeded()
        profile.refreshTikTokPlacesAfterImport()
    }

    /// Handles photo tap to show fullscreen gallery.
    private func handlePhotoTapped(photos: [UIImage], index: Int) {
        galleryPhotos = photos
        selectedImageIndex = index
        galleryPresentationCount += 1
        showPhotoGallery = true
    }

    /// Handles navigation to a different place (e.g., after TikTok association change).
    private func handlePlaceNavigation(newPlaceId: String) {
        selectedPlaceVM.navigateToPlace(placeId: newPlaceId)
    }

    /// Handles list selection sheet dismissal.
    private func handleListSelectionDismiss() {
        tabsViewModel?.refreshPlaceListMembership()
        listSelectionViewModel = nil
    }

    /// Handles list selection sheet state changes.
    private func handleListSelectionChanged(_ newValue: Bool) {
        guard newValue, listSelectionViewModel == nil else { return }
        listSelectionViewModel = PlaceListSelectionViewModel(
            profile: profile,
            userSession: userSession
        )
    }

    // MARK: - ViewModel Initialization

    /// Initializes the ViewModel with data-driven callbacks.
    private func initializeViewModelIfNeeded() {
        guard tabsViewModel == nil else { return }

        let vm = PlaceDetailTabsViewModel(
            userSession: userSession,
            profileVM: profile,
            detailPlaceViewModel: detailPlaceViewModel,
            selectedPlaceVM: selectedPlaceVM
        )

        vm.onDismissMaxFavoritesAlert = { [weak profile] in
            profile?.favoritesViewModel.showMaxFavoritesAlert = false
        }

        vm.configureSaversViewModel(userProfileNavigationViewModel: userProfileNavigationViewModel)

        configureInitialData(for: vm)

        tabsViewModel = vm
    }

    /// Configures initial data for the ViewModel.
    private func configureInitialData(for vm: PlaceDetailTabsViewModel) {
        guard let place = selectedPlaceVM.selectedPlace else { return }

        vm.setPlace(place)
        vm.setPosts(selectedPlaceVM.posts, rating: selectedPlaceVM.placeRating)

        let isFavorited = profile.isPlaceFavorite(placeId: place.id.uuidString)
        vm.setFavoriteStatus(isFavorited)

        let userVideos = profile.getTikTokVideosSync(for: place.id.uuidString)
        vm.setTikTokVideos(placeVideos: selectedPlaceVM.tiktokVideos, userVideos: userVideos)

        let loadingState = selectedPlaceVM.postLoadingState(forPlaceId: place.id.uuidString)
        vm.setPostLoadingState(mapLoadingState(loadingState))

        if let currentLocation = locationManager.currentLocation {
            vm.travelTimeViewModel.updateTravelTime(for: place, from: currentLocation.coordinate)
        }
    }

    /// Maps SelectedPlaceViewModel loading state to PlacePostsViewModel loading state.
    private func mapLoadingState(_ state: SelectedPlaceViewModel.LoadingState) -> PlacePostsViewModel.LoadingState {
        switch state {
        case .idle:
            return .idle
        case .loading:
            return .loading
        case .loaded:
            return .loaded
        case .error(let error):
            return .error(error)
        }
    }
}
