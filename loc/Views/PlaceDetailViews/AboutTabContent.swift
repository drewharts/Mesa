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
    
    /// Callback when the user taps the Review action
    let onAddPost: () -> Void

    /// Callback to open the private note editor (action row pill and note card Edit button)
    let onEditNote: () -> Void

    /// Whether a manual refresh is currently in progress
    var isRefreshing: Bool = false

    /// Callback to manually refresh place data
    var onRefresh: (() -> Void)? = nil

    // MARK: - View-Owned Presentation State
    @StateObject private var insightsViewModel = PlaceInsightsViewModel()
    @StateObject private var reservationViewModel = ReservationViewModel()
    @StateObject private var damnlinesWaitViewModel = DamnlinesWaitViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 1. DUMB COMPONENT: rating, summary and the action row
            if let place = viewModel.place {
                PlaceInfoSection(
                    place: place,
                    isRefreshing: isRefreshing,
                    onRefresh: onRefresh,
                    onAddPost: onAddPost,
                    onNoteTapped: onEditNote,
                    takeText: insightsViewModel.take,
                    reservation: reservationViewModel.link,
                    onReserveTapped: { reservationViewModel.trackTap() },
                    waitInfo: damnlinesWaitViewModel.info
                )
            }

            // 2. Friends first + "People order" from TikTok mentions
            if insightsViewModel.hasContent {
                PlaceInsightsSection(viewModel: insightsViewModel)
                    .padding(.top, 12)
            }

            // 3. User's private note (only shown if note exists)
            PlaceNoteDisplayView(
                viewModel: viewModel.notesViewModel,
                onEditTapped: onEditNote
            )

            // 4. Would Go Back scale (only shown if reviews have sentiment data)
            if viewModel.wouldReturnStats.hasData {
                WouldReturnScaleView(stats: viewModel.wouldReturnStats)
                    .padding(.top, 12)
            }
        }
        .task(id: viewModel.placeId) {
            await insightsViewModel.load(placeId: viewModel.placeId)
        }
        .task(id: viewModel.placeId) {
            await reservationViewModel.load(placeId: viewModel.placeId, place: viewModel.place)
        }
        .task(id: viewModel.placeId) {
            await damnlinesWaitViewModel.load(placeId: viewModel.placeId)
        }
        .onReceive(insightsViewModel.$priorityPhotoURLs) { urls in
            viewModel.placePhotosViewModel.priorityPhotoURLs = urls
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
    let externalVideosVM = ExternalVideosViewModel()
    let photosVM = PlacePhotosViewModel()
    let customPlaceCreatorVM = CustomPlaceCreatorViewModel(
        placeService: services.placeService
    )
    let notesVM = NotesTabViewModel(userSession: userSession)

    // Create coordinator ViewModel (fully refactored - no ViewModel dependencies)
    let aboutVM = AboutTabViewModel(
        externalVideosViewModel: externalVideosVM,
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
        onAddPost: { print("Add post tapped") },
        onEditNote: { print("Edit note tapped") }
    )
    .environmentObject(profileVM)
    .environmentObject(userSession)
    .padding()
}
