//
//  NotesTabContent.swift
//  loc
//
//  Created by Cursor on 1/22/25.
//  Refactored to use proper MVVM with NotesTabViewModel
//

import SwiftUI

struct NotesTabContent: View {
    @ObservedObject var viewModel: NotesTabViewModel
    
    var body: some View {
        PlaceNoteView(viewModel: viewModel)
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
        reviewService: services.reviewService,
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
        reviewService: services.reviewService,
        locationManager: locationManager,
        deepLinkManager: services.deepLinkManager,
        deepLinkViewModel: nil
    )
    
    let notesVM = NotesTabViewModel(
        userService: services.userService,
        selectedPlaceVM: selectedPlaceVM,
        profileVM: profileVM,
        userSession: userSession
    )
    
    var mockPlace = DetailPlace()
    mockPlace.name = "Sample Restaurant"
    selectedPlaceVM.selectedPlace = mockPlace
    
    return NotesTabContent(viewModel: notesVM)
        .padding()
}
