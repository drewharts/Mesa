//
//  PlaceDetailNavigationViewModel.swift
//  loc
//
//  ViewModel for PlaceDetailViewInNavigation.
//  Single Responsibility: Fetch place details by ID for in-navigation display.
//

import Foundation

@MainActor
class PlaceDetailNavigationViewModel: ObservableObject {
    // MARK: - Published State
    @Published var isLoading: Bool = true
    @Published var loadError: Error?
    @Published var loadedPlace: DetailPlace?

    // MARK: - Dependencies
    private let placeId: String
    private let placeService = PlaceService.shared

    // MARK: - Initialization

    /// Initializes the ViewModel with a place ID to fetch.
    init(placeId: String) {
        self.placeId = placeId
    }

    // MARK: - Actions

    /// Fetches the full place details from the backend by place ID.
    /// Uses a cached copy (e.g. prefetched from a trip) when available so the sheet opens instantly.
    func loadPlace() async {
        if let cached = TripDataCache.shared.place(for: placeId) {
            loadedPlace = cached
            isLoading = false
            // Quiet background refresh for next time
            let id = placeId
            Task { [placeService] in
                if let fresh = try? await placeService.fetchPlace(withId: id) {
                    TripDataCache.shared.storePlace(fresh, id: id)
                }
            }
            return
        }
        do {
            let place = try await placeService.fetchPlace(withId: placeId)
            loadedPlace = place
            TripDataCache.shared.storePlace(place, id: placeId)
            isLoading = false
        } catch {
            loadError = error
            isLoading = false
            print("❌ [PlaceDetailNavigationVM] Error loading place details: \(error)")
        }
    }
}
