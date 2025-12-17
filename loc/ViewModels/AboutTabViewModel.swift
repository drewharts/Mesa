//
//  AboutTabViewModel.swift
//  loc
//
//  Created by Cursor on 1/22/25.
//  Coordinator ViewModel for AboutTabContent - manages child ViewModels
//

import Foundation
import UIKit
import Combine

@MainActor
class AboutTabViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var place: DetailPlace?
    @Published var placeId: String = ""
    
    // MARK: - Child ViewModels
    let tikTokVideosViewModel: TikTokVideosViewModel
    let placePhotosViewModel: PlacePhotosViewModel
    let customPlaceCreatorViewModel: CustomPlaceCreatorViewModel
    let notesViewModel: NotesTabViewModel
    
    // MARK: - Dependencies
    private let selectedPlaceVM: SelectedPlaceViewModel
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(tikTokVideosViewModel: TikTokVideosViewModel,
         placePhotosViewModel: PlacePhotosViewModel,
         customPlaceCreatorViewModel: CustomPlaceCreatorViewModel,
         notesViewModel: NotesTabViewModel,
         selectedPlaceVM: SelectedPlaceViewModel) {
        self.tikTokVideosViewModel = tikTokVideosViewModel
        self.placePhotosViewModel = placePhotosViewModel
        self.customPlaceCreatorViewModel = customPlaceCreatorViewModel
        self.notesViewModel = notesViewModel
        self.selectedPlaceVM = selectedPlaceVM
        
        setupObservers()
    }
    
    // MARK: - Setup
    private func setupObservers() {
        // Observe place changes
        selectedPlaceVM.$selectedPlace
            .sink { [weak self] place in
                self?.place = place
                self?.placeId = place?.id.uuidString ?? ""
                // Update custom place creator VM when place changes
                self?.customPlaceCreatorViewModel.setPlace(place)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Computed Properties
    var externalRating: Double? {
        place?.rating
    }
    
    var reviewCount: Int? {
        place?.userRatingsTotal
    }
    
    var placeDescription: String {
        place?.description ?? "No description available"
    }
    
    /// Whether this is a custom place
    var isCustomPlace: Bool {
        place?.isCustom == true
    }
}

