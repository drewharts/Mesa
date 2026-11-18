//
//  CitySaveViewModel.swift
//  loc
//
//  SMART ViewModel: saves places into the user's real city list (one-tap save and imports).
//  Single Responsibility: resolve the city list for a place (find case-insensitively, else create),
//  add the place, and describe the result for the "Added to New York City" banner.
//

import Foundation

/// Where a batch of saved places ended up.
struct CitySaveSummary: Equatable {
    /// Distinct list names the places went to, in first-use order.
    var listNames: [String] = []
    var added: Int = 0
    var alreadyThere: Int = 0
    var failed: Int = 0
    /// Place id -> list id for rows this save created (not ones that were already there), so they can be undone.
    var newlyAdded: [String: String] = [:]
    /// Place ids that are now in a city list, whether this save added them or they were already there.
    var handledIds: Set<String> = []

    /// Banner text: "Added to New York City", "Added 4 places to Tokyo", or "Added 5 places to 2 lists".
    var message: String? {
        let saved = added + alreadyThere
        guard saved > 0 else { return nil }
        let base: String
        if saved == 1, let name = listNames.first {
            base = "Added to \(name)"
        } else if listNames.count == 1, let name = listNames.first {
            base = "Added \(saved) places to \(name)"
        } else {
            base = "Added \(saved) places to \(listNames.count) lists"
        }
        return failed > 0 ? "\(base) (\(failed) failed)" : base
    }
}

/// Why a city save couldn't start.
enum CitySaveError: LocalizedError {
    case notSignedIn

    var errorDescription: String? { "Not signed in" }
}

@MainActor
final class CitySaveViewModel: ObservableObject {
    private let profile: ProfileViewModel
    private let userSession: UserSession
    private let placeListService: PlaceListService

    /// One find-or-create per city at a time, so a burst of imports can't create the list twice.
    private static var inFlight: [String: Task<LightweightPlaceList, Error>] = [:]

    /// Creates the view model; `placeListService` is injectable for tests.
    init(profile: ProfileViewModel, userSession: UserSession, placeListService: PlaceListService = .shared) {
        self.profile = profile
        self.userSession = userSession
        self.placeListService = placeListService
    }

    /// Saves places to their city lists and reports where they went. Placeholder-id places are skipped.
    func save(_ places: [DetailPlace]) async -> CitySaveSummary {
        var summary = CitySaveSummary()
        for place in places where !PlaceIdGuard.isPlaceholder(place.id.uuidString) {
            do {
                let list = try await listForCity(of: place)
                let wasAdded = try await add(place, to: list)
                summary.handledIds.insert(place.id.uuidString)
                if wasAdded {
                    summary.added += 1
                    summary.newlyAdded[place.id.uuidString] = list.list_id
                } else {
                    summary.alreadyThere += 1
                }
                if !summary.listNames.contains(list.name) { summary.listNames.append(list.name) }
            } catch {
                print("❌ [CitySaveViewModel] Save of \(place.id.uuidString) failed: \(error)")
                summary.failed += 1
            }
        }
        return summary
    }

    /// Finds or creates the city list a place belongs in.
    private func listForCity(of place: DetailPlace) async throws -> LightweightPlaceList {
        let city = await resolveCity(of: place)
        let name = city ?? CityListMatcher.fallbackListName
        let key = CityListMatcher.cityKey(name)
        if let running = Self.inFlight[key] { return try await running.value }
        let task = Task { try await self.findOrCreateList(named: name, city: city) }
        Self.inFlight[key] = task
        defer { Self.inFlight[key] = nil }
        return try await task.value
    }

    /// Adds the place unless the list already has it. Returns true when a row was added.
    private func add(_ place: DetailPlace, to list: LightweightPlaceList) async throws -> Bool {
        if try await placeListService.isPlaceInList(listId: list.list_id, placeId: place.id.uuidString) { return false }
        try await profile.listsViewModel.addPlaceToLightweightListAndWait(listId: list.list_id, place: place)
        return true
    }

    /// Matches the user's current lists by name; creates the list when none is the city.
    private func findOrCreateList(named name: String, city: String?) async throws -> LightweightPlaceList {
        guard let userId = userSession.currentUserId else { throw CitySaveError.notSignedIn }
        // A failed fetch must abort: creating blind could duplicate an existing city list.
        let lists = try await placeListService.fetchAllListMetadata(userId: userId)
        if let existing = CityListMatcher.match(cityName: name, in: lists) { return existing }
        switch await profile.listsViewModel.addNewPlaceList(named: name, city: city ?? "", emoji: "", image: "") {
        case .success(let created):
            return LightweightPlaceList(list_id: created.id.uuidString, name: created.name, is_public: true, image: nil,
                                        created_at: nil, updated_at: nil, distance_meters: nil, place_count: 0, city: city)
        case .failure(let error):
            throw error
        }
    }

    /// City from the place's own fields, else the backend's stored city, else reverse geocoding; nil if all fail.
    private func resolveCity(of place: DetailPlace) async -> String? {
        if let city = CityListMatcher.cityName(storedCity: place.city, address: place.address) { return city }
        let stored = try? await placeListService.fetchPlaceCities(placeIds: [place.id.uuidString])
        if let backend = stored?[place.id.uuidString.lowercased()],
           let city = CityListMatcher.cityName(storedCity: backend, address: nil) { return city }
        guard let coordinate = place.coordinate, let locality = await PlaceCityGeocoder.locality(of: coordinate) else { return nil }
        return CityListMatcher.cityName(storedCity: locality, address: nil)
    }
}
