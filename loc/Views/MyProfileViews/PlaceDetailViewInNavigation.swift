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

            // Clear selected place to remove selection indicator when navigating back to list
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
/// Data-Driven: Drives ViewModel updates via .onChange() instead of ViewModel observing other ViewModels
struct PlaceDetailViewContent: View {
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
                // Refresh TikTok places when place detail view appears
                profile.refreshTikTokPlacesAfterImport()
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
                selectedPlaceVM: selectedPlaceVM,
                profile: profile
            ))
            .modifier(TikTokChangeHandler(
                tabsViewModel: $tabsViewModel,
                selectedPlaceVM: selectedPlaceVM,
                profile: profile
            ))

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

        // Wire up callback to dismiss max favorites alert in ProfileViewModel
        vm.onDismissMaxFavoritesAlert = { [weak profile] in
            profile?.showMaxFavoritesAlert = false
        }

        // Configure savers VM for navigation
        vm.configureSaversViewModel(userProfileViewModel: userProfileViewModel)

        // Set initial data
        if let place = selectedPlaceVM.selectedPlace {
            vm.setPlace(place)
            vm.setPosts(selectedPlaceVM.posts, rating: selectedPlaceVM.placeRating)

            // Set favorite status
            let isFavorited = profile.isPlaceFavorite(placeId: place.id.uuidString)
            vm.setFavoriteStatus(isFavorited)

            // Set TikTok videos
            let userVideos = profile.getTikTokVideosSync(for: place.id.uuidString)
            vm.setTikTokVideos(placeVideos: selectedPlaceVM.tiktokVideos, userVideos: userVideos)

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
