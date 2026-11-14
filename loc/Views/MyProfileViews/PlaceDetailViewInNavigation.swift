//
//  PlaceDetailViewInNavigation.swift
//  loc
//
//  Wrapper view for PlaceDetailView when used in NavigationStack.
//  Single Responsibility: Present PlaceDetailView without NavigationView wrapper.
//  MVVM: Uses PlaceDetailNavigationViewModel for data fetching,
//  coordinates with SelectedPlaceViewModel via .task modifier.

import SwiftUI

struct PlaceDetailViewInNavigation: View {
    let minSheetHeight: CGFloat
    let shouldAnimateMap: Bool

    @StateObject private var viewModel: PlaceDetailNavigationViewModel
    @ObservedObject private var ownership = PlaceDetailOwnership.shared
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var userProfileNavigationVM: UserProfileNavigationViewModel
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel

    /// Identifies this page in the ownership stack.
    @State private var ownerToken = UUID()
    /// The place this page shows. The shared selection is put back to it if something else overwrites it.
    @State private var ownedPlace: DetailPlace?
    /// How many times this page has put its place back (capped by PlaceDetailOwnerStack.maxReasserts).
    @State private var reassertCount = 0

    init(placeId: String, minSheetHeight: CGFloat, shouldAnimateMap: Bool = false) {
        self.minSheetHeight = minSheetHeight
        self.shouldAnimateMap = shouldAnimateMap
        self._viewModel = StateObject(wrappedValue: PlaceDetailNavigationViewModel(placeId: placeId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                PlaceDetailSkeletonView()
            } else if let error = viewModel.loadError {
                VStack(spacing: 16) {
                    Text("Error loading place")
                        .font(.headline)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                PlaceDetailViewContent(minSheetHeight: minSheetHeight, onWillChangePlace: { newPlace in
                    // The page itself moves to another place (e.g. video re-association): own that one.
                    adopt(newPlace)
                })
                    .environmentObject(selectedPlaceVM)
                    .environmentObject(profile)
                    .environmentObject(locationManager)
                    .environmentObject(userProfileNavigationVM)
                    .environmentObject(userSession)
                    .environmentObject(detailPlaceViewModel)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadPlace()
            // The user tapped another place while this one loaded (this view was replaced and its
            // task cancelled): don't select the old place over the new one.
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if let place = viewModel.loadedPlace {
                    adopt(place)
                    selectedPlaceVM.selectPlace(place, shouldAnimateMap: shouldAnimateMap)
                    selectedPlaceVM.isDetailSheetPresented = false
                }
            }
        }
        .onAppear {
            // Back on screen (e.g. popped back to this page): reclaim the selection for this place.
            guard let ownedPlace else { return }
            ownership.claim(token: ownerToken, placeId: ownedPlace.id.uuidString)
            reconcileSelection()
        }
        .onDisappear {
            ownership.release(token: ownerToken)
        }
        .onChange(of: selectedPlaceVM.selectedPlace?.id) { _, _ in
            reconcileSelection()
        }
        .onChange(of: ownership.stack.top) { _, _ in
            reconcileSelection()
        }
    }

    /// Makes the given place this page's place and marks the page as the visible owner.
    private func adopt(_ place: DetailPlace) {
        ownedPlace = place
        ownership.claim(token: ownerToken, placeId: place.id.uuidString)
    }

    /// Puts this page's place back when a stale or unrelated write replaced the shared selection.
    private func reconcileSelection() {
        guard let ownedPlace else { return }
        let selected = selectedPlaceVM.selectedPlace
        let decision = PlaceDetailOwnerStack.decide(
            isTopOwner: ownership.isTop(ownerToken),
            ownedPlaceId: ownedPlace.id.uuidString,
            ownedGooglePlaceId: ownedPlace.googlePlaceId,
            selectedPlaceId: selected?.id.uuidString,
            selectedGooglePlaceId: selected?.googlePlaceId,
            isGlobalDetailSheetPresented: selectedPlaceVM.isDetailSheetPresented,
            reassertsSoFar: reassertCount
        )
        switch decision {
        case .keep:
            break
        case .adopt:
            if let selected { adopt(selected) }
        case .reassert:
            reassertCount += 1
            selectedPlaceVM.selectPlace(ownedPlace, shouldAnimateMap: false)
            selectedPlaceVM.isDetailSheetPresented = false
        }
    }
}

/// Content view extracted from PlaceDetailView to work without NavigationView wrapper
/// Single Responsibility: Display place detail content (reusable in both sheet and navigation contexts)
/// Data-Driven: Drives ViewModel updates via .onChange() instead of ViewModel observing other ViewModels
struct PlaceDetailViewContent: View {
    let minSheetHeight: CGFloat
    /// Called before the page moves itself to another place, so an owning wrapper can follow it.
    var onWillChangePlace: ((DetailPlace) -> Void)? = nil

    @State private var selectedImageIndex: Int?
    @State private var showPhotoGallery = false
    @State private var galleryPhotoURLs: [String] = []
    @State private var galleryPresentationCount = 0
    @State private var showNoPhoneNumberAlert = false
    @State private var showListSelection = false
    @State private var showCreatePost = false
    @State private var listSelectionViewModel: PlaceListSelectionViewModel?
    @State private var tripSelectionViewModel: PlaceTripSelectionViewModel?

    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var userProfileNavigationVM: UserProfileNavigationViewModel
    @EnvironmentObject var userSession: UserSession
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
                        onPhotoTapped: { photoURLs, index in
                            galleryPhotoURLs = photoURLs
                            selectedImageIndex = index
                            galleryPresentationCount += 1
                            showPhotoGallery = true
                        },
                        onAddToList: { showListSelection = true },
                        onAddReview: { showCreatePost = true },
                        onPlaceChanged: { newPlace in
                            // Navigate to the new place after video association change
                            onWillChangePlace?(newPlace)
                            selectedPlaceVM.selectPlaceAndFetchDetails(newPlace, shouldAnimateMap: true)
                        }
                    )
                    .environmentObject(userProfileNavigationVM)
                    .environmentObject(detailPlaceViewModel)
                }
            }
            .frame(maxWidth: .infinity)
            .ignoresSafeArea(edges: [.bottom, .horizontal])
            .onAppear {
                initializeViewModelIfNeeded()
            }
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
                tripSelectionViewModel = nil
            }) {
                if let selectedPlace = selectedPlaceVM.selectedPlace,
                   let viewModel = listSelectionViewModel {
                    ListSelectionSheet(
                        viewModel: viewModel,
                        place: selectedPlace,
                        listsVM: profile.listsViewModel,
                        isPresented: $showListSelection,
                        tripSelectionViewModel: tripSelectionViewModel
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
                    tripSelectionViewModel = PlaceTripSelectionViewModel()
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
                // Refresh external places when place detail view appears
                profile.externalContentViewModel.refreshExternalPlacesAfterImport()
            }
            // MARK: - Data-Driven Updates (View drives ViewModel state via modifiers)
            .modifier(PlaceChangeHandler(
                tabsViewModel: $tabsViewModel,
                selectedPlaceVM: selectedPlaceVM,
                profile: profile,
                locationManager: locationManager
            ))
            .modifier(FavoritesChangeHandler(
                tabsViewModel: $tabsViewModel,
                favoritesVM: profile.favoritesViewModel
            ))
            .modifier(ExternalContentChangeHandler(
                tabsViewModel: $tabsViewModel,
                selectedPlaceVM: selectedPlaceVM,
                profile: profile,
                externalContentVM: profile.externalContentViewModel
            ))

            // Photo Gallery Overlay (Pinterest-style) - fills entire sheet
            if showPhotoGallery, let selectedIndex = selectedImageIndex {
                PinterestPhotoGalleryView(
                    photoURLs: galleryPhotoURLs,
                    initialIndex: selectedIndex,
                    isPresented: $showPhotoGallery
                )
                .id(galleryPresentationCount) // Force fresh view on each presentation
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .navigationBarHidden(showPhotoGallery)
    }

    // MARK: - Private Methods

    /// Initializes the ViewModel with data-driven callbacks.
    private func initializeViewModelIfNeeded() {
        guard tabsViewModel == nil else { return }

        // Create ViewModel - all child VMs are now fully refactored with data-driven approach
        let vm = PlaceDetailTabsViewModel(
            userSession: userSession,
            profileVM: profile,
            detailPlaceViewModel: detailPlaceViewModel,
            selectedPlaceVM: selectedPlaceVM
        )

        // Configure savers VM for navigation
        vm.configureSaversViewModel(userProfileNavigationViewModel: userProfileNavigationVM)

        // Set initial data
        if let place = selectedPlaceVM.selectedPlace {
            vm.setPlace(place)
            vm.setPosts(selectedPlaceVM.posts, rating: selectedPlaceVM.placeRating)

            // Set external videos
            let userVideos = profile.externalContentViewModel.getExternalVideosSync(for: place.id.uuidString)
            vm.setExternalVideos(placeVideos: selectedPlaceVM.externalVideos, userVideos: userVideos)

            // Set post loading state
            let loadingState = selectedPlaceVM.postLoadingState(forPlaceId: place.id.uuidString)
            vm.setPostLoadingState(mapLoadingState(loadingState))

            // Calculate travel time
            if let currentLocation = locationManager.currentLocation {
                vm.travelTimeViewModel.updateTravelTime(for: place, from: currentLocation.coordinate)
            }
        }

        tabsViewModel = vm
    }

    /// Maps PlacePostsCacheService loading state to PlacePostsViewModel loading state.
    private func mapLoadingState(_ state: PlacePostsCacheService.LoadingState) -> PlacePostsViewModel.LoadingState {
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
