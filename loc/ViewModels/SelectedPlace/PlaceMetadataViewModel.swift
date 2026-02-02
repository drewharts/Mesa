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

    // MARK: - Dependencies

    private let mesaBackendService: MesaBackendService
    private let placeService: PlaceService

    // MARK: - Initialization

    /// Initializes with required services.
    init(mesaBackendService: MesaBackendService, placeService: PlaceService) {
        self.mesaBackendService = mesaBackendService
        self.placeService = placeService
    }

    // MARK: - Public Methods

    /// Computes and stores metadata for a place.
    func computeMetadata(for place: DetailPlace) {
        // Set rating
        placeRating = place.rating ?? 0

        // Compute open status
        isRestaurantOpen = OpenStatusService.isOpen(place)

        // Calculate and store restaurant type
        calculateAndStoreRestaurantType(for: place)
    }

    /// Returns the restaurant type for a place.
    func getRestaurantType(forPlaceId placeId: String) -> String? {
        return restaurantTypes[placeId]
    }

    /// Refreshes external ratings if they're missing.
    func refreshExternalRatingsIfNeeded(for place: DetailPlace, onUpdate: @escaping (DetailPlace) -> Void) {
        // Skip if we already have valid ratings
        if let rating = place.rating, rating > 0, place.userRatingsTotal != nil {
            return
        }

        let placeId = place.id.uuidString

        Task {
            do {
                let updatedPlace = try await mesaBackendService.fetchPlaceDetails(placeId: placeId)

                await MainActor.run {
                    // Merge rating data into the place
                    var mergedPlace = place
                    mergedPlace.rating = updatedPlace.rating
                    mergedPlace.userRatingsTotal = updatedPlace.userRatingsTotal

                    self.placeRating = updatedPlace.rating ?? 0
                    onUpdate(mergedPlace)

                    // Update Firestore in background
                    self.updatePlaceInFirestore(mergedPlace)
                }
            } catch {
                print("❌ [PlaceMetadataVM] Failed to fetch ratings for '\(place.name)': \(error.localizedDescription)")
            }
        }
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

    /// Updates place in Firestore with fresh data.
    private func updatePlaceInFirestore(_ place: DetailPlace) {
        placeService.updatePlace(place: place) { error in
            if let error = error {
                print("❌ [PlaceMetadataVM] Failed to update place in Firestore: \(error.localizedDescription)")
            }
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
