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

    // MARK: - Concurrency

    private static let maxConcurrentRequests = 6
    private var importTask: Task<Void, Never>?

    /// Result of resolving one extracted place.
    private enum ResolveOutcome: Sendable {
        case resolved(ImportedPlace)
        case failed(String)
    }

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
            guard !Task.isCancelled else { return }
            extractResult = result
            listName = result.listName

            if result.places.isEmpty {
                importState = .failed(message: "No places could be extracted from this list.")
                return
            }
        } catch {
            guard !Task.isCancelled else { return }
            extractResult = nil
            importState = .failed(message: error.localizedDescription)
            return
        }

        // Phase 2: Resolve each place individually
        await resolvePlaces()
    }

    /// Resolves extracted places with bounded concurrency, keeping input order and reporting "n of total" progress.
    private func resolvePlaces() async {
        guard let places = extractResult?.places, !places.isEmpty else { return }

        resolvedPlaces = []
        resolveErrors = []
        importState = .resolvingPlaces(current: 0, total: places.count)

        let outcomes = await resolveConcurrently(places)
        guard !Task.isCancelled else { return }

        for outcome in outcomes {
            switch outcome {
            case .resolved(let place): resolvedPlaces.append(place)
            case .failed(let message): resolveErrors.append(message)
            case .none: break
            }
        }

        if resolvedPlaces.isEmpty {
            importState = .failed(message: "No places could be resolved from this list.")
        } else {
            importState = .idle
        }
    }

    /// Runs resolve requests through a sliding window of `maxConcurrentRequests`, returning outcomes in input order.
    private func resolveConcurrently(_ places: [ExtractedPlace]) async -> [ResolveOutcome?] {
        var outcomes = [ResolveOutcome?](repeating: nil, count: places.count)
        let service = importService
        var nextIndex = 0
        var completed = 0

        await withTaskGroup(of: (Int, ResolveOutcome).self) { group in
            while nextIndex < min(Self.maxConcurrentRequests, places.count) {
                let index = nextIndex
                let place = places[index]
                group.addTask { (index, await Self.resolveOne(place, using: service)) }
                nextIndex += 1
            }

            for await (index, outcome) in group {
                outcomes[index] = outcome
                completed += 1
                importState = .resolvingPlaces(current: completed, total: places.count)

                if Task.isCancelled {
                    group.cancelAll()
                } else if nextIndex < places.count {
                    let next = nextIndex
                    let place = places[next]
                    group.addTask { (next, await Self.resolveOne(place, using: service)) }
                    nextIndex += 1
                }
            }
        }
        return outcomes
    }

    /// Resolves a single place, mapping any failure into a displayable message.
    private nonisolated static func resolveOne(_ place: ExtractedPlace, using service: GoogleMapsImportService) async -> ResolveOutcome {
        do {
            let result = try await service.resolvePlace(
                name: place.name, latitude: place.latitude, longitude: place.longitude
            )
            if result.resolved, let resolved = result.place {
                return .resolved(resolved)
            }
            return .failed(result.error ?? "Could not resolve: \(place.name ?? "unknown")")
        } catch {
            let label = place.name ?? "(\(place.latitude), \(place.longitude))"
            return .failed("Could not resolve: \(label)")
        }
    }

    // MARK: - Task Ownership & Cancellation

    /// Starts the extract-and-resolve flow in a task owned by this view model so it can be cancelled.
    func startExtraction() {
        importTask?.cancel()
        importTask = Task { [weak self] in
            await self?.extractPlaces()
        }
    }

    /// Cancels any in-flight extract/resolve task and returns to a clean idle state if it was mid-flight.
    func cancelImport() {
        importTask?.cancel()
        importTask = nil

        switch importState {
        case .extracting, .resolvingPlaces:
            importState = .idle
            extractResult = nil
            resolvedPlaces = []
            resolveErrors = []
        default:
            break
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

    /// Adds places to a list with bounded concurrency (no batch endpoint exists), reporting "n of total" progress.
    private func addPlacesLoop(places: [ImportedPlace], listId: String, userId: String) async {
        let service = userService
        var nextIndex = 0
        var completed = 0
        importState = .addingPlaces(current: 0, total: places.count)

        await withTaskGroup(of: Void.self) { group in
            while nextIndex < min(Self.maxConcurrentRequests, places.count) {
                let place = places[nextIndex]
                group.addTask { await Self.addOne(place, listId: listId, userId: userId, using: service) }
                nextIndex += 1
            }

            for await _ in group {
                completed += 1
                importState = .addingPlaces(current: completed, total: places.count)
                if nextIndex < places.count {
                    let place = places[nextIndex]
                    group.addTask { await Self.addOne(place, listId: listId, userId: userId, using: service) }
                    nextIndex += 1
                }
            }
        }
    }

    /// Adds one place to a list, logging (not throwing) on failure.
    private nonisolated static func addOne(_ place: ImportedPlace, listId: String, userId: String, using service: SupabaseUserService) async {
        do {
            try await service.addPlaceToList(listId: listId, placeId: place.id, addedBy: userId)
        } catch {
            print("Failed to add place \(place.name) to list: \(error.localizedDescription)")
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
        importTask?.cancel()
        importTask = nil
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
