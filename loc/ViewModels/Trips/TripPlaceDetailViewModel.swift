//
//  TripPlaceDetailViewModel.swift
//  loc
//
//  Self-contained ViewModel that loads a DetailPlace for inline trip place detail
//

import Foundation

/// Loads and holds a DetailPlace for display in the trip place detail view.
@MainActor
class TripPlaceDetailViewModel: ObservableObject {
    @Published var place: DetailPlace?
    @Published var isLoading: Bool = true
    @Published var error: String?

    private let placeService = PlaceService.shared
    private let placeId: String

    init(placeId: String) {
        self.placeId = placeId
    }

    /// Fetches place details from the PlaceService and updates published state.
    func loadPlace() async {
        isLoading = true
        error = nil
        do {
            place = try await placeService.fetchPlaceDetails(placeId: placeId)
            if place == nil {
                error = "Place not found"
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
