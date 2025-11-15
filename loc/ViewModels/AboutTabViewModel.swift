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
    
    // MARK: - Dependencies
    private let selectedPlaceVM: SelectedPlaceViewModel
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(tikTokVideosViewModel: TikTokVideosViewModel,
         placePhotosViewModel: PlacePhotosViewModel,
         selectedPlaceVM: SelectedPlaceViewModel) {
        self.tikTokVideosViewModel = tikTokVideosViewModel
        self.placePhotosViewModel = placePhotosViewModel
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
}

