//
//  PlaceMetadataViewModel.swift
//  loc
//
//  Manages place metadata including ratings, restaurant type, and open status.
//  Single Responsibility: Only handles place metadata computation and caching.
//

import Foundation
import CoreLocation

@MainActor
class PlaceMetadataViewModel: ObservableObject {
    // MARK: - Published Properties

    /// The Google rating for the current place.
    @Published var placeRating: Double = 0

    /// Whether the current place is open.
    @Published var isRestaurantOpen: Bool = false

    // MARK: - Private Storage

    /// Dictionary to store restaurant types by placeId.
    private var restaurantTypes: [String: String] = [:]

    // MARK: - Public Methods

    /// Computes and stores metadata for a place.
    func computeMetadata(for place: DetailPlace) {
        placeRating = place.rating ?? 0
        isRestaurantOpen = OpenStatusService.isOpen(place)
        calculateAndStoreRestaurantType(for: place)
    }

    /// Returns the restaurant type for a place.
    func getRestaurantType(forPlaceId placeId: String) -> String? {
        return restaurantTypes[placeId]
    }

    // MARK: - Private Methods

    /// Calculates and stores the restaurant type for a place.
    private func calculateAndStoreRestaurantType(for place: DetailPlace) {
        let placeId = place.id.uuidString
        let placeDetailVM = PlaceDetailViewModel()
        if let type = placeDetailVM.getRestaurantType(for: place) {
            restaurantTypes[placeId] = type
        }
    }

    // MARK: - Cleanup

    /// Clears all metadata.
    func clearAllData() {
        placeRating = 0
        isRestaurantOpen = false
        restaurantTypes.removeAll()
    }
}
