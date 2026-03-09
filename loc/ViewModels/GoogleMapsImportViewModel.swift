//
//  GoogleMapsImportViewModel.swift
//  loc
//
//  ViewModel: Manages the two-phase Google Maps list import flow
//  Single Responsibility: Coordinate extraction + per-place resolution via backend, then list creation
//
//  State flow: idle -> extracting -> resolvingPlaces -> idle (with results) -> creatingList -> addingPlaces -> completed
//

import Foundation

/// Represents the current stage of the Google Maps import flow.
enum GoogleMapsImportState: Equatable {
    case idle
    case extracting
    case resolvingPlaces(current: Int, total: Int)
    case creatingList
    case addingPlaces(current: Int, total: Int)
    case completed(listId: String)
    case failed(message: String)

    /// Equatable conformance for associated-value cases.
    static func == (lhs: GoogleMapsImportState, rhs: GoogleMapsImportState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.extracting, .extracting), (.creatingList, .creatingList):
            return true
        case (.resolvingPlaces(let lc, let lt), .resolvingPlaces(let rc, let rt)):
            return lc == rc && lt == rt
        case (.addingPlaces(let lc, let lt), .addingPlaces(let rc, let rt)):
            return lc == rc && lt == rt
        case (.completed(let l), .completed(let r)):
            return l == r
        case (.failed(let l), .failed(let r)):
            return l == r
        default:
            return false
        }
    }
}

@MainActor
class GoogleMapsImportViewModel: ObservableObject {
    // MARK: - Published State

    @Published var url: String = ""
    @Published var listName: String = ""
    @Published var importState: GoogleMapsImportState = .idle
    @Published var extractResult: GoogleMapsExtractResult?
    @Published var resolvedPlaces: [ImportedPlace] = []
    @Published var resolveErrors: [String] = []

    // List picker pagination state
    @Published var availableLists: [LightweightPlaceList] = []
    @Published var isLoadingLists: Bool = false
    @Published var hasMoreLists: Bool = true

    // MARK: - Dependencies

    private let importService = GoogleMapsImportService()
    private let placeService = SupabasePlaceService.shared
    private let userService = SupabaseUserService.shared

    // MARK: - List Pagination

    private var listsCurrentPage: Int = 0
    private let listsPageSize: Int = 20

    // MARK: - URL Extraction & Validation

    /// Extracts a URL from pasted text that may include labels (e.g. "Omakase · Author https://maps.app.goo.gl/...").
    private func extractURL(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = trimmed.range(of: #"https?://\S+"#, options: .regularExpression) {
            return String(trimmed[range])
        }
        return nil
    }

    /// Validates whether the given string contains a Google Maps URL.
    func isValidGoogleMapsURL(_ text: String) -> Bool {
        let lowered = text.lowercased()
        let patterns = [
            "maps.google.com",
            "google.com/maps",
            "maps.app.goo.gl",
            "goo.gl/maps"
        ]
        return patterns.contains { lowered.contains($0) }
    }

    // MARK: - Two-Phase Extract & Resolve

    /// Extracts places from the pasted URL, then resolves each one individually with progress feedback.
    func extractPlaces() async {
        let trimmedInput = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidGoogleMapsURL(trimmedInput) else {
            importState = .failed(message: "Please enter a valid Google Maps list URL.")
            return
        }

        let cleanURL = extractURL(from: trimmedInput) ?? trimmedInput
        importState = .extracting

        // Phase 1: Extract place names and coordinates
        do {
            let result = try await importService.extractList(url: cleanURL)
            extractResult = result
            listName = result.listName

            if result.places.isEmpty {
                importState = .failed(message: "No places could be extracted from this list.")
                return
            }
        } catch {
            extractResult = nil
            importState = .failed(message: error.localizedDescription)
            return
        }

        // Phase 2: Resolve each place individually
        await resolvePlaces()
    }

    /// Resolves each extracted place via the backend, updating progress per-place.
    private func resolvePlaces() async {
        guard let places = extractResult?.places, !places.isEmpty else { return }

        resolvedPlaces = []
        resolveErrors = []

        for (index, place) in places.enumerated() {
            importState = .resolvingPlaces(current: index + 1, total: places.count)

            do {
                let result = try await importService.resolvePlace(
                    name: place.name,
                    latitude: place.latitude,
                    longitude: place.longitude
                )

                if result.resolved, let resolved = result.place {
                    resolvedPlaces.append(resolved)
                } else {
                    let errorMsg = result.error ?? "Could not resolve: \(place.name ?? "unknown")"
                    resolveErrors.append(errorMsg)
                }
            } catch {
                let label = place.name ?? "(\(place.latitude), \(place.longitude))"
                resolveErrors.append("Could not resolve: \(label)")
            }
        }

        if resolvedPlaces.isEmpty {
            importState = .failed(message: "No places could be resolved from this list.")
        } else {
            importState = .idle
        }
    }

    // MARK: - Create List with Places

    /// Creates a new Mesa list and adds all resolved places to it, updating progress per-place.
    func createListWithPlaces(userId: String) async {
        guard !resolvedPlaces.isEmpty else { return }

        let finalName = listName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalName.isEmpty else {
            importState = .failed(message: "Please enter a list name.")
            return
        }

        importState = .creatingList

        do {
            let newList = try await placeService.createNewList(
                userId: userId, name: finalName, city: "", emoji: "", image: ""
            )
            let listId = newList.id.uuidString

            await addPlacesLoop(places: resolvedPlaces, listId: listId, userId: userId)

            importState = .completed(listId: listId)
        } catch {
            importState = .failed(message: "Failed to create list: \(error.localizedDescription)")
        }
    }

    // MARK: - Add to Existing List

    /// Adds all resolved places to an existing list, skipping list creation.
    func addPlacesToExistingList(listId: String, listName: String, userId: String) async {
        guard !resolvedPlaces.isEmpty else { return }

        self.listName = listName
        await addPlacesLoop(places: resolvedPlaces, listId: listId, userId: userId)

        importState = .completed(listId: listId)
    }

    // MARK: - Shared Add-Places Loop

    /// Adds an array of places to a list one at a time with progress updates.
    private func addPlacesLoop(places: [ImportedPlace], listId: String, userId: String) async {
        for (index, place) in places.enumerated() {
            importState = .addingPlaces(current: index + 1, total: places.count)

            do {
                try await userService.addPlaceToList(
                    listId: listId,
                    placeId: place.id,
                    addedBy: userId
                )
            } catch {
                print("Failed to add place \(place.name) to list: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - List Picker Loading

    /// Fetches the first page of the user's lists for the import picker.
    func loadInitialLists(userId: String) async {
        guard !userId.isEmpty else { return }
        listsCurrentPage = 1
        isLoadingLists = true
        hasMoreLists = true

        do {
            let lists = try await userService.fetchPlaceListsWithoutLocation(
                userId: userId, page: 1, pageSize: listsPageSize
            )
            availableLists = lists
            hasMoreLists = lists.count >= listsPageSize
        } catch {
            print("GoogleMapsImportViewModel: Failed to fetch lists: \(error)")
        }

        isLoadingLists = false
    }

    /// Fetches the next page of lists and appends to the existing results.
    func loadMoreLists(userId: String) async {
        guard !userId.isEmpty, hasMoreLists, !isLoadingLists else { return }

        listsCurrentPage += 1
        isLoadingLists = true

        do {
            let lists = try await userService.fetchPlaceListsWithoutLocation(
                userId: userId, page: listsCurrentPage, pageSize: listsPageSize
            )
            let existingIds = Set(availableLists.map(\.list_id))
            let newLists = lists.filter { !existingIds.contains($0.list_id) }
            availableLists.append(contentsOf: newLists)
            hasMoreLists = lists.count >= listsPageSize
        } catch {
            print("GoogleMapsImportViewModel: Failed to load more lists: \(error)")
            listsCurrentPage -= 1
        }

        isLoadingLists = false
    }

    // MARK: - Reset

    /// Resets the import flow back to the initial state.
    func reset() {
        url = ""
        listName = ""
        importState = .idle
        extractResult = nil
        resolvedPlaces = []
        resolveErrors = []
        availableLists = []
        isLoadingLists = false
        hasMoreLists = true
        listsCurrentPage = 0
    }
}
