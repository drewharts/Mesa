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
    @Published var wouldReturnStats: WouldReturnStats = WouldReturnStats(wouldReturnCount: 0, wouldNotReturnCount: 0)

    // MARK: - Child ViewModels
    let externalVideosViewModel: ExternalVideosViewModel
    let placePhotosViewModel: PlacePhotosViewModel
    let customPlaceCreatorViewModel: CustomPlaceCreatorViewModel
    let notesViewModel: NotesTabViewModel

    // MARK: - Dependencies (Services only)
    private let placeService: PlaceService

    // MARK: - Callbacks
    /// Called when a place description is fetched from polling
    var onDescriptionUpdated: ((String) -> Void)?

    // MARK: - Private State
    private var descriptionPollingTimer: Timer?

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

    deinit {
        descriptionPollingTimer?.invalidate()
    }

    // MARK: - Data-Driven Methods

    /// Sets the current place and updates child ViewModels.
    func setPlace(_ place: DetailPlace?) {
        self.place = place
        self.placeId = place?.id.uuidString ?? ""
        externalVideosViewModel.setPlaceId(place?.id.uuidString)
        customPlaceCreatorViewModel.setPlace(place)
        checkDescriptionAndStartPolling(for: place)
    }

    // MARK: - Description Polling

    /// Checks if the place needs a description and starts polling if so.
    private func checkDescriptionAndStartPolling(for place: DetailPlace?) {
        descriptionPollingTimer?.invalidate()

        guard let place = place else {
            isDescriptionLoading = false
            return
        }

        // Placeholder UUIDs don't exist in Supabase — skip polling
        guard !place.hasPlaceholderID else {
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

    /// Starts a timer to poll for the description every 3 seconds.
    private func startDescriptionPolling(placeId: String) {
        descriptionPollingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.pollForDescription(placeId: placeId)
            }
        }
    }

    /// Fetches the place from the backend and checks if description is ready.
    private func pollForDescription(placeId: String) async {
        do {
            let updatedPlace = try await placeService.fetchPlace(withId: placeId)
            if let description = updatedPlace.description, !description.isEmpty {
                // Description is ready - update and stop polling
                descriptionPollingTimer?.invalidate()
                isDescriptionLoading = false
                // Notify parent via callback
                onDescriptionUpdated?(description)
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

