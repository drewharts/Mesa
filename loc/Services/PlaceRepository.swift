//
//  PlaceRepository.swift
//  loc
//
//  Orchestrates the fetch-enrich-persist lifecycle for place data.
//  ViewModels call this instead of calling MesaBackendService directly.
//

import Foundation
import CoreLocation

@MainActor
class PlaceRepository {
    static let shared = PlaceRepository()

    private let mesaBackendService = MesaBackendService.shared

    private init() {}

    /// Resolves a place by fetching from backend and merging with existing data.
    /// When googlePlaceId is available, fetches directly. Otherwise resolves by
    /// name + coordinate via /maps/resolve-place to obtain the Google Place ID first.
    func resolvePlace(
        googlePlaceId: String?,
        fallbackId: String,
        existingPlace: DetailPlace
    ) async throws -> DetailPlace {
        if let googlePlaceId, !googlePlaceId.isEmpty {
            return try await resolveByGooglePlaceId(googlePlaceId, existingPlace: existingPlace)
        }

        if let coordinate = existingPlace.coordinate {
            return try await resolveByNameAndCoordinate(existingPlace, coordinate: coordinate)
        }

        // Last resort: try fallback UUID
        return try await resolveByGooglePlaceId(fallbackId, existingPlace: existingPlace)
    }

    // MARK: - Private Methods

    /// Fetches full details using a Google Place ID and merges with existing data.
    private func resolveByGooglePlaceId(_ placeId: String, existingPlace: DetailPlace) async throws -> DetailPlace {
        let freshPlace = try await mesaBackendService.fetchPlaceDetails(placeId: placeId, source: "google")
        return PlaceDataAssembler.merge(base: existingPlace, overlay: freshPlace)
    }

    /// Resolves a place by name and coordinate via backend search, then fetches full details.
    /// Validates the resolved place is within 200m of the expected coordinate.
    private func resolveByNameAndCoordinate(_ existingPlace: DetailPlace, coordinate: CLLocationCoordinate2D) async throws -> DetailPlace {
        let suggestions = try await mesaBackendService.fetchSuggestions(
            query: existingPlace.name,
            limit: 3,
            provider: "google",
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )

        guard let bestMatch = suggestions.first else {
            throw PlaceResolutionError.couldNotResolve(name: existingPlace.name)
        }

        let freshPlace = try await mesaBackendService.fetchPlaceDetails(
            placeId: bestMatch.id,
            source: bestMatch.source
        )

        let merged = PlaceDataAssembler.merge(base: existingPlace, overlay: freshPlace)

        if let freshCoordinate = merged.coordinate,
           !isWithinDistance(freshCoordinate, of: coordinate, thresholdMeters: 200) {
            throw PlaceResolutionError.couldNotResolve(name: existingPlace.name)
        }

        return merged
    }

    /// Returns true if two coordinates are within the given distance threshold.
    private func isWithinDistance(
        _ coord1: CLLocationCoordinate2D,
        of coord2: CLLocationCoordinate2D,
        thresholdMeters: Double
    ) -> Bool {
        let loc1 = CLLocation(latitude: coord1.latitude, longitude: coord1.longitude)
        let loc2 = CLLocation(latitude: coord2.latitude, longitude: coord2.longitude)
        return loc1.distance(from: loc2) <= thresholdMeters
    }
}

/// Errors specific to place resolution.
enum PlaceResolutionError: LocalizedError {
    case couldNotResolve(name: String)

    var errorDescription: String? {
        switch self {
        case .couldNotResolve(let name):
            return "Could not resolve place: \(name)"
        }
    }
}
