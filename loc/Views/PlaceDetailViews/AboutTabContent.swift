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
    
    let onPhotoTapped: ([UIImage], Int) -> Void

    /// Callback when user changes a TikTok's place association - parent should navigate to new place
    var onPlaceChanged: ((String) -> Void)?

    // MARK: - View-Owned Presentation State
    @State private var showingNoteSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // NOTE: CustomPlaceCreatorView moved to PlaceDetailTabsView type row
            
            // 1. DUMB COMPONENT: Pure display of place info
            if let place = viewModel.place {
                PlaceInfoSection(place: place)
            }
            
            // 2. User's private note (only shown if note exists)
            PlaceNoteDisplayView(
                viewModel: viewModel.notesViewModel,
                onEditTapped: { showingNoteSheet = true }
            )
            
            // 3. SMART COMPONENT: TikTok videos with their own ViewModel
            TikTokVideosSection(
                viewModel: viewModel.tikTokVideosViewModel,
                placeId: viewModel.placeId,
                selectedPlace: viewModel.place,
                onPlaceChanged: onPlaceChanged
            )
            .environmentObject(profile)
            .environmentObject(userSession)
            
            // 4. SMART COMPONENT: Photos with its own ViewModel
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
    
    // Create child ViewModels
    let tikTokVM = TikTokVideosViewModel(
        tikTokService: TikTokPlaceService.shared,
        selectedPlaceVM: selectedPlaceVM,
        profileVM: profileVM
    )
    
    let photosVM = PlacePhotosViewModel(
        postService: services.postService,
        selectedPlaceVM: selectedPlaceVM
    )
    
    let customPlaceCreatorVM = CustomPlaceCreatorViewModel(
        placeService: services.placeService
    )
    
    let notesVM = NotesTabViewModel(
        userService: services.userService,
        selectedPlaceVM: selectedPlaceVM,
        profileVM: profileVM,
        userSession: userSession
    )
    
    // Create coordinator ViewModel
    let aboutVM = AboutTabViewModel(
        tikTokVideosViewModel: tikTokVM,
        placePhotosViewModel: photosVM,
        customPlaceCreatorViewModel: customPlaceCreatorVM,
        notesViewModel: notesVM,
        selectedPlaceVM: selectedPlaceVM
    )
    
    var mockPlace = DetailPlace()
    mockPlace.name = "Sample Restaurant"
    mockPlace.description = "A cozy Italian restaurant."
    mockPlace.rating = 4.5
    mockPlace.userRatingsTotal = 234
    selectedPlaceVM.selectedPlace = mockPlace
    
    return AboutTabContent(
        viewModel: aboutVM,
        onPhotoTapped: { photos, index in
            print("Tapped photo at index: \(index)")
        }
    )
    .environmentObject(profileVM)
    .environmentObject(userSession)
    .padding()
}
