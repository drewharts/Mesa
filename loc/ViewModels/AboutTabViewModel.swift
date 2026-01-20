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
    @Published var isDescriptionLoading: Bool = false

    // MARK: - Child ViewModels
    let tikTokVideosViewModel: TikTokVideosViewModel
    let placePhotosViewModel: PlacePhotosViewModel
    let customPlaceCreatorViewModel: CustomPlaceCreatorViewModel
    let notesViewModel: NotesTabViewModel

    // MARK: - Dependencies
    private let selectedPlaceVM: SelectedPlaceViewModel
    private let placeService: PlaceService
    private var cancellables = Set<AnyCancellable>()
    private var descriptionPollingTimer: Timer?
    
    // MARK: - Initialization
    init(tikTokVideosViewModel: TikTokVideosViewModel,
         placePhotosViewModel: PlacePhotosViewModel,
         customPlaceCreatorViewModel: CustomPlaceCreatorViewModel,
         notesViewModel: NotesTabViewModel,
         selectedPlaceVM: SelectedPlaceViewModel,
         placeService: PlaceService = .shared) {
        self.tikTokVideosViewModel = tikTokVideosViewModel
        self.placePhotosViewModel = placePhotosViewModel
        self.customPlaceCreatorViewModel = customPlaceCreatorViewModel
        self.notesViewModel = notesViewModel
        self.selectedPlaceVM = selectedPlaceVM
        self.placeService = placeService

        setupObservers()
    }

    deinit {
        descriptionPollingTimer?.invalidate()
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
                // Check if we need to poll for description
                self?.checkDescriptionAndStartPolling(for: place)
            }
            .store(in: &cancellables)
    }

    // MARK: - Description Polling

    /// Checks if the place needs a description and starts polling if so
    private func checkDescriptionAndStartPolling(for place: DetailPlace?) {
        descriptionPollingTimer?.invalidate()

        guard let place = place else {
            isDescriptionLoading = false
            return
        }

        // If description is nil/empty and not a custom place, start polling
        let hasDescription = place.description != nil && !place.description!.isEmpty
        if !hasDescription && place.isCustom != true {
            isDescriptionLoading = true
            startDescriptionPolling(placeId: place.id.uuidString)
        } else {
            isDescriptionLoading = false
        }
    }

    /// Starts a timer to poll for the description every 3 seconds
    private func startDescriptionPolling(placeId: String) {
        descriptionPollingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.pollForDescription(placeId: placeId)
            }
        }
    }

    /// Fetches the place from the backend and checks if description is ready
    private func pollForDescription(placeId: String) async {
        do {
            let updatedPlace = try await placeService.fetchPlace(withId: placeId)
            if let description = updatedPlace.description, !description.isEmpty {
                // Description is ready - update and stop polling
                descriptionPollingTimer?.invalidate()
                isDescriptionLoading = false
                // Update the selected place with new description
                selectedPlaceVM.updatePlaceDescription(description)
            }
        } catch {
            print("❌ [AboutTabViewModel] Error polling for description: \(error)")
        }
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

