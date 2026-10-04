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
    @Published var wouldReturnStats: WouldReturnStats = WouldReturnStats(wouldReturnCount: 0, wouldNotReturnCount: 0)

    // MARK: - Child ViewModels
    let externalVideosViewModel: ExternalVideosViewModel
    let placePhotosViewModel: PlacePhotosViewModel
    let customPlaceCreatorViewModel: CustomPlaceCreatorViewModel
    let notesViewModel: NotesTabViewModel

    // MARK: - Dependencies (Services only)
    private let placeService: PlaceService

    // MARK: - Initialization
    /// Initializes the coordinator ViewModel with child ViewModels.
    init(externalVideosViewModel: ExternalVideosViewModel,
         placePhotosViewModel: PlacePhotosViewModel,
         customPlaceCreatorViewModel: CustomPlaceCreatorViewModel,
         notesViewModel: NotesTabViewModel) {
        self.externalVideosViewModel = externalVideosViewModel
        self.placePhotosViewModel = placePhotosViewModel
        self.customPlaceCreatorViewModel = customPlaceCreatorViewModel
        self.notesViewModel = notesViewModel
        self.placeService = ServiceContainer.shared.placeService
    }

    // MARK: - Data-Driven Methods

    /// Sets the current place and updates child ViewModels.
    func setPlace(_ place: DetailPlace?) {
        self.place = place
        self.placeId = place?.id.uuidString ?? ""
        externalVideosViewModel.setPlaceId(place?.id.uuidString)
        customPlaceCreatorViewModel.setPlace(place)
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

