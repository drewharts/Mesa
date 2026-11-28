//
//  ExternalVideosSection.swift
//  loc
//
//  Created by Cursor on 1/22/25.
//  Compact "Help Improve Detection" row shown when a place has external videos (videos live in the media strip)
//

import SwiftUI

struct ExternalVideosSection: View {
    @ObservedObject var viewModel: ExternalVideosViewModel
    @EnvironmentObject var profile: ProfileViewModel

    let selectedPlace: DetailPlace?

    /// Callback when user changes the place association - parent should navigate to new place
    var onPlaceChanged: ((DetailPlace) -> Void)?

    /// Videos themselves live in the media strip; this only keeps the compact "Help Improve Detection" row,
    /// shown when external videos exist for the place.
    var body: some View {
        if viewModel.hasVideos, let place = selectedPlace {
            PlaceFlaggingView(
                place: place,
                videos: viewModel.videos,
                onPlaceChanged: onPlaceChanged
            )
            .environmentObject(profile)
        }
    }
}

// MARK: - Preview
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

    // Create ViewModel (fully refactored - no ViewModel dependencies)
    let externalVideosVM = ExternalVideosViewModel()

    var mockPlace = DetailPlace()
    mockPlace.name = "Sample Restaurant"

    // Set sample videos
    externalVideosVM.setPlaceId("test-place-123")

    return ExternalVideosSection(
        viewModel: externalVideosVM,
        selectedPlace: mockPlace
    )
    .environmentObject(profileVM)
    .environmentObject(userSession)
    .padding()
}

