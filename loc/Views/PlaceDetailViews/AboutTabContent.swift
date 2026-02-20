//
//  AboutTabContent.swift
//  loc
//
//  Created by Cursor on 1/22/25.
//  Refactored to use proper MVVM with child components
//

import SwiftUI
import UIKit

struct AboutTabContent: View {
    // MARK: - Primary ViewModel (Coordinator)
    @ObservedObject var viewModel: AboutTabViewModel
    
    // MARK: - Still needed for child components (temporary)
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var userSession: UserSession
    
    let onPhotoTapped: ([String], Int) -> Void  // URLs instead of UIImages

    /// Callback when user taps the "Share something..." button to create a post
    let onAddPost: () -> Void

    /// Callback when user changes a TikTok's place association - parent should navigate to new place
    var onPlaceChanged: ((DetailPlace) -> Void)?

    /// Whether a manual refresh is currently in progress
    var isRefreshing: Bool = false

    /// Callback to manually refresh place data
    var onRefresh: (() -> Void)? = nil

    // MARK: - View-Owned Presentation State
    @State private var showingNoteSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // NOTE: CustomPlaceCreatorView moved to PlaceDetailTabsView type row

            // 1. DUMB COMPONENT: Pure display of place info
            if let place = viewModel.place {
                PlaceInfoSection(
                    place: place,
                    isDescriptionLoading: viewModel.isDescriptionLoading,
                    isRefreshing: isRefreshing,
                    onRefresh: onRefresh,
                    onAddPost: onAddPost
                )
            }
            
            // 2. User's private note (only shown if note exists)
            PlaceNoteDisplayView(
                viewModel: viewModel.notesViewModel,
                onEditTapped: { showingNoteSheet = true }
            )
            
            // 3. Would Go Back scale (only shown if reviews have sentiment data)
            if viewModel.wouldReturnStats.hasData {
                WouldReturnScaleView(stats: viewModel.wouldReturnStats)
            }

            // 4. SMART COMPONENT: TikTok videos with their own ViewModel
            TikTokVideosSection(
                viewModel: viewModel.tikTokVideosViewModel,
                placeId: viewModel.placeId,
                selectedPlace: viewModel.place,
                onPlaceChanged: onPlaceChanged
            )
            .environmentObject(profile)
            .environmentObject(userSession)

            // 5. SMART COMPONENT: Photos with its own ViewModel
            PlacePhotosView(
                viewModel: viewModel.placePhotosViewModel,
                onPhotoTapped: onPhotoTapped
            )
            .padding(.top, 20)
        }
        .sheet(isPresented: $showingNoteSheet) {
            PlaceNoteSheetView(viewModel: viewModel.notesViewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Preview (Much Simpler!)
#Preview {
    let services = ServiceContainer.shared
    let locationManager = LocationManager()
    
    let detailPlaceVM = DetailPlaceViewModel(
        placeService: services.placeService,
        userService: services.userService
    )
    
    let selectedPlaceVM = SelectedPlaceViewModel(
        locationManager: locationManager,
        postService: services.postService,
        placeService: services.placeService,
        userService: services.userService,
        imageService: services.imageService,
        detailPlaceViewModel: detailPlaceVM
    )
    
    let userSession = UserSession(
        userService: services.userService,
        locationManager: locationManager,
        detailPlaceVM: detailPlaceVM
    )
    
    let profileVM = ProfileViewModel(
        userSession: userSession,
        userService: services.userService,
        detailPlaceViewModel: detailPlaceVM,
        imageService: services.imageService,
        placeService: services.placeService,
        postService: services.postService,
        locationManager: locationManager,
        deepLinkManager: services.deepLinkManager,
        deepLinkViewModel: nil
    )
    
    // Create child ViewModels (all fully refactored - no ViewModel dependencies)
    let tikTokVM = TikTokVideosViewModel()
    let photosVM = PlacePhotosViewModel()
    let customPlaceCreatorVM = CustomPlaceCreatorViewModel(
        placeService: services.placeService
    )
    let notesVM = NotesTabViewModel(userSession: userSession)

    // Create coordinator ViewModel (fully refactored - no ViewModel dependencies)
    let aboutVM = AboutTabViewModel(
        tikTokVideosViewModel: tikTokVM,
        placePhotosViewModel: photosVM,
        customPlaceCreatorViewModel: customPlaceCreatorVM,
        notesViewModel: notesVM
    )

    var mockPlace = DetailPlace()
    mockPlace.name = "Sample Restaurant"
    mockPlace.description = "A cozy Italian restaurant."
    mockPlace.rating = 4.5
    mockPlace.userRatingsTotal = 234

    // Set place data on refactored ViewModels
    aboutVM.setPlace(mockPlace)
    photosVM.setPlace(mockPlace)
    notesVM.setPlace(mockPlace)

    return AboutTabContent(
        viewModel: aboutVM,
        onPhotoTapped: { photos, index in
            print("Tapped photo at index: \(index)")
        },
        onAddPost: { print("Add post tapped") }
    )
    .environmentObject(profileVM)
    .environmentObject(userSession)
    .padding()
}
