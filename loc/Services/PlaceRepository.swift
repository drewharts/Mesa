//
//  PlaceRepository.swift
//  loc
//
//  Orchestrates the fetch-enrich-persist lifecycle for place data.
//  ViewModels call this instead of calling MesaBackendService directly.
//

import Foundation

@MainActor
class PlaceRepository {
    static let shared = PlaceRepository()

    private let mesaBackendService = MesaBackendService.shared

    private init() {}

    /// Resolves a place by fetching from backend and merging with existing data.
    /// Backend checks Supabase cache first, then falls back to external APIs.
    func resolvePlace(
        googlePlaceId: String?,
        fallbackId: String,
        existingPlace: DetailPlace
    ) async throws -> DetailPlace {
        let lookupId = googlePlaceId ?? fallbackId
        let freshPlace = try await mesaBackendService.fetchPlaceDetails(placeId: lookupId, source: "google")
        return PlaceDataAssembler.merge(base: existingPlace, overlay: freshPlace)
    }
}
