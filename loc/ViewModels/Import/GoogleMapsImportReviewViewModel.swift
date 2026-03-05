//
//  GoogleMapsImportReviewViewModel.swift
//  loc
//
//  Created by Claude on 2/9/26.
//
//  SMART ViewModel: Manages place resolution, selection, and batch import.
//  Single Responsibility: Resolving raw imported places and executing batch imports.
//

import Foundation
import CoreLocation
import Combine

@MainActor
class GoogleMapsImportReviewViewModel: ObservableObject {

    // MARK: - Published State

    @Published var resolvedPlaces: [ResolvedImportPlace] = []
    @Published var resolutionProgress: Int = 0
    @Published var totalToResolve: Int = 0
    @Published var isResolving: Bool = false

    @Published var importProgress: Int = 0
    @Published var importTotal: Int = 0
    @Published var isImporting: Bool = false
    @Published var importSummary: ImportSummary?

    // MARK: - Computed Properties

    /// Returns the number of selected, matched places ready for import.
    var selectedCount: Int {
        resolvedPlaces.filter { $0.isSelected && isMatched($0) }.count
    }

    /// Returns whether all matchable places are selected.
    var allSelected: Bool {
        resolvedPlaces.filter { isMatched($0) }.allSatisfy { $0.isSelected }
    }

    // MARK: - Dependencies

    private let mesaBackendService = MesaBackendService.shared
    private let supabasePlaceService = SupabasePlaceService.shared
    private let userService = UserService.shared

    // MARK: - Public API

    /// Resolves raw imported places to full DetailPlace objects via the backend search API.
    func resolveAllPlaces(_ rawPlaces: [GoogleMapsImportPlace]) async {
        isResolving = true
        totalToResolve = rawPlaces.count
        resolutionProgress = 0

        resolvedPlaces = rawPlaces.map { place in
            ResolvedImportPlace(
                id: place.id,
                originalPlace: place,
                status: .pending
            )
        }

        // Process in batches of 3 concurrent requests
        let batchSize = 3
        for batchStart in stride(from: 0, to: rawPlaces.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, rawPlaces.count)
            let batch = Array(rawPlaces[batchStart..<batchEnd])

            await withTaskGroup(of: (UUID, PlaceResolutionStatus).self) { group in
                for place in batch {
                    group.addTask { [weak self] in
                        guard let self = self else {
                            return (place.id, .failed("Service unavailable"))
                        }
                        let status = await self.resolvePlace(place)
                        return (place.id, status)
                    }
                }

                for await (placeId, status) in group {
                    updatePlaceStatus(placeId: placeId, status: status)
                    resolutionProgress += 1
                }
            }
        }

        isResolving = false
    }

    /// Toggles the selection state of a place by ID.
    func toggleSelection(for placeId: UUID) {
        guard let index = resolvedPlaces.firstIndex(where: { $0.id == placeId }) else { return }
        resolvedPlaces[index].isSelected.toggle()
    }

    /// Sets all matchable places to the given selection state.
    func selectAll(_ selected: Bool) {
        for index in resolvedPlaces.indices {
            if isMatched(resolvedPlaces[index]) {
                resolvedPlaces[index].isSelected = selected
            }
        }
    }

    /// Imports all selected, matched places to the specified list.
    func performBatchImport(userId: String, listId: String) async -> ImportSummary {
        let placesToImport = resolvedPlaces.filter { $0.isSelected && isMatched($0) }
        isImporting = true
        importTotal = placesToImport.count
        importProgress = 0

        var imported = 0
        var failed = 0

        for resolved in placesToImport {
            guard case .matched(let detailPlace) = resolved.status else { continue }

            do {
                try await supabasePlaceService.ensurePlaceExists(place: detailPlace)
                try await userService.addPlaceToList(
                    listId: listId,
                    placeId: detailPlace.id.uuidString,
                    addedBy: userId
                )
                imported += 1
            } catch {
                print("❌ [GoogleMapsImport] Failed to import \(detailPlace.name): \(error)")
                failed += 1
            }

            importProgress += 1
        }

        let skipped = resolvedPlaces.count - placesToImport.count
        let summary = ImportSummary(imported: imported, failed: failed, skipped: skipped)
        importSummary = summary
        isImporting = false
        return summary
    }

    // MARK: - Private Methods

    /// Resolves a single raw place to a DetailPlace via backend search.
    private func resolvePlace(_ place: GoogleMapsImportPlace) async -> PlaceResolutionStatus {
        do {
            let suggestions = try await mesaBackendService.fetchSuggestions(
                query: place.name,
                limit: 3,
                provider: "google",
                latitude: place.coordinate?.latitude,
                longitude: place.coordinate?.longitude
            )

            guard let bestMatch = suggestions.first else {
                return .failed("Place not found")
            }

            let detailPlace = try await mesaBackendService.fetchPlaceDetails(
                placeId: bestMatch.id,
                source: bestMatch.source
            )

            return .matched(detailPlace)
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// Updates the status of a specific place in the resolved list.
    private func updatePlaceStatus(placeId: UUID, status: PlaceResolutionStatus) {
        guard let index = resolvedPlaces.firstIndex(where: { $0.id == placeId }) else { return }
        resolvedPlaces[index].status = status

        // Auto-deselect failed places
        if case .failed = status {
            resolvedPlaces[index].isSelected = false
        }
    }

    /// Returns whether a resolved place has been successfully matched.
    private func isMatched(_ place: ResolvedImportPlace) -> Bool {
        if case .matched = place.status { return true }
        return false
    }
}
