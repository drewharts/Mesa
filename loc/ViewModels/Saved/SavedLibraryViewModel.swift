//
//  SavedLibraryViewModel.swift
//  loc
//
//  PROTOTYPE (auto_sort_saved). Loads the places the user already has (lists, favorites,
//  my places, imports) with read-only queries, then sorts them on device with SavedLibraryBuilder.
//  Writes nothing.
//

import CoreLocation
import Foundation
import Supabase

@MainActor
final class SavedLibraryViewModel: ObservableObject {
    /// What the top picker is showing: a smart group or one city.
    enum Scope: Hashable {
        case smart(SavedSmartGroup.Kind)
        case city(String) // SavedCityGroup.key
    }

    @Published private(set) var library: SavedLibrary = .empty
    @Published private(set) var isLoading = false
    @Published private(set) var loadError: String?
    @Published var scope: Scope? { didSet { if oldValue != scope { selectedType = nil; selectedCuisine = nil } } }
    @Published var selectedType: SavedPlaceType? { didSet { if oldValue != selectedType { selectedCuisine = nil } } }
    @Published var selectedCuisine: String?

    private var hasLoaded = false

    // MARK: - Derived

    /// Cities with at least 3 places get their own chip; the rest live under "More".
    var primaryCities: [SavedCityGroup] {
        library.cities.filter { $0.places.count >= 3 && $0.name != SavedLibraryBuilder.unknownCityName }
    }
    var otherCities: [SavedCityGroup] {
        let primary = Set(primaryCities.map(\.key))
        return library.cities.filter { !primary.contains($0.key) }
    }

    var scopeTitle: String {
        switch scope {
        case .smart(let kind): return library.smartGroups.first { $0.kind == kind }?.title ?? ""
        case .city(let key): return library.cities.first { $0.key == key }?.name ?? ""
        case nil: return ""
        }
    }

    /// Places in the current scope (before type / cuisine filters).
    var scopedPlaces: [SavedLibraryPlace] {
        switch scope {
        case .smart(let kind): return library.smartGroups.first { $0.kind == kind }?.places ?? []
        case .city(let key): return library.cities.first { $0.key == key }?.places ?? []
        case nil: return []
        }
    }

    var typeCounts: [(type: SavedPlaceType, count: Int)] {
        let places = scopedPlaces
        return SavedPlaceType.allCases.compactMap { t in
            let n = places.filter { $0.type == t }.count
            return n > 0 ? (t, n) : nil
        }
    }

    /// Cuisines for the selected type, most common first (only for Restaurants).
    var cuisineCounts: [(cuisine: String, count: Int)] {
        guard selectedType == .restaurants else { return [] }
        var counts: [String: Int] = [:]
        for p in scopedPlaces where p.type == .restaurants { if let c = p.cuisine { counts[c, default: 0] += 1 } }
        return counts.map { ($0.key, $0.value) }.sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0 < $1.0 }
    }

    /// Places after type and cuisine filters.
    var filteredPlaces: [SavedLibraryPlace] {
        scopedPlaces.filter { p in
            (selectedType == nil || p.type == selectedType) && (selectedCuisine == nil || p.cuisine == selectedCuisine)
        }
    }

    /// Type sections for the "All" view.
    var sections: [(type: SavedPlaceType, places: [SavedLibraryPlace])] {
        let places = scopedPlaces
        return SavedPlaceType.allCases.compactMap { t in
            let list = places.filter { $0.type == t }
            return list.isEmpty ? nil : (t, list)
        }
    }

    // MARK: - Loading

    func loadIfNeeded(userId: String?, location: CLLocation?) async {
        guard !hasLoaded else { return }
        await load(userId: userId, location: location)
    }

    func load(userId: String?, location: CLLocation?) async {
        guard let userId, !userId.isEmpty else { return }
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            let inputs = try await Self.fetchInputs(userId: userId)
            let userLocation = location.map { (lat: $0.coordinate.latitude, lon: $0.coordinate.longitude) }
            let built = await Task.detached(priority: .userInitiated) {
                SavedLibraryBuilder.build(inputs, userLocation: userLocation)
            }.value
            library = built
            hasLoaded = true
            if scope == nil || !isScopeValid(scope) { scope = defaultScope(in: built) }
        } catch {
            loadError = "Couldn't load your places. Pull to retry."
        }
    }

    private func isScopeValid(_ scope: Scope?) -> Bool {
        switch scope {
        case .smart(let kind): return library.smartGroups.contains { $0.kind == kind }
        case .city(let key): return library.cities.contains { $0.key == key }
        case nil: return false
        }
    }

    /// Near you when there is anything nearby, else the biggest city.
    private func defaultScope(in lib: SavedLibrary) -> Scope? {
        if lib.smartGroups.contains(where: { $0.kind == .nearYou }) { return .smart(.nearYou) }
        if let first = lib.cities.first { return .city(first.key) }
        return nil
    }

    // MARK: - Data (read-only)

    /// Reads list / favorite / my-place places, imports, and one-tap saves (favorites rows, which carry
    /// a timestamp) and returns one input per row (dupes are merged later).
    private static func fetchInputs(userId: String) async throws -> [SavedPlaceInput] {
        async let saved = PlaceService.shared.fetchAllUserPlaces(userId: userId)
        async let imports = fetchRows(table: "external_places", timeColumn: "added_at", userId: userId)
        async let quickSaves = fetchRows(table: "favorites", timeColumn: "timestamp", userId: userId)
        let savedPlaces = try await saved
        let importRows = (try? await imports) ?? []
        let quickSaveRows = (try? await quickSaves) ?? []

        var inputs = savedPlaces.map { input(from: $0, source: .list, addedAt: nil) }

        // Reuse loaded places when we have them, batch-fetch the rest.
        var known: [String: DetailPlace] = [:]
        for p in savedPlaces { known[p.id.uuidString.lowercased()] = p }
        let rowIds = (importRows + quickSaveRows).map(\.placeId)
        let missing = Array(Set(rowIds.filter { known[$0] == nil }))
        for chunk in stride(from: 0, to: missing.count, by: 50).map({ Array(missing[$0..<min($0 + 50, missing.count)]) }) {
            // place ids are stored uppercase; ask for both spellings.
            let ids = chunk + chunk.map { $0.uppercased() }
            if let places = try? await PlaceService.shared.fetchPlaceDetailsBatch(placeIds: ids) {
                for p in places { known[p.id.uuidString.lowercased()] = p }
            }
        }
        for row in importRows {
            guard let place = known[row.placeId] else { continue }
            inputs.append(input(from: place, source: .imported, addedAt: row.addedAt))
        }
        for row in quickSaveRows {
            guard let place = known[row.placeId] else { continue }
            inputs.append(input(from: place, source: .saved, addedAt: row.addedAt))
        }
        return inputs
    }

    private struct TimedRow { let placeId: String; let addedAt: Date? }

    /// The user's rows in `table` (place id + when added), newest first, paged past Supabase's 1,000-row cap.
    private static func fetchRows(table: String, timeColumn: String, userId: String) async throws -> [TimedRow] {
        struct Raw: Decodable {
            let place_id: String?
            let time: String?
            enum CodingKeys: String, CodingKey { case place_id, time }
        }
        let userIds = Array(Set([userId, userId.uppercased(), userId.lowercased()]))
        var rows: [TimedRow] = []
        let pageSize = 1000
        var offset = 0
        while offset < 10_000 {
            // "time:<column>" aliases the timestamp column so one decoder fits both tables.
            let page: [Raw] = try await SupabaseManager.shared.client
                .from(table)
                .select("place_id, time:\(timeColumn)")
                .in("user_id", values: userIds)
                .order(timeColumn, ascending: false)
                .range(from: offset, to: offset + pageSize - 1)
                .execute()
                .value
            rows += page.compactMap { raw in
                raw.place_id.map { TimedRow(placeId: $0.lowercased(), addedAt: SavedLibraryBuilder.parseTimestamp(raw.time)) }
            }
            if page.count < pageSize { break }
            offset += pageSize
        }
        return rows
    }

    private static func input(from place: DetailPlace, source: SavedPlaceInput.Source, addedAt: Date?) -> SavedPlaceInput {
        SavedPlaceInput(
            id: place.id.uuidString,
            name: place.name,
            address: place.address,
            storedCity: place.city,
            latitude: place.coordinate?.latitude,
            longitude: place.coordinate?.longitude,
            categories: place.categories ?? [],
            userCorrectedCategory: place.userCorrectedCategory,
            googlePlaceId: place.googlePlaceId,
            isDinnerSpot: TonightCategoryClassifier.fit(place, vibe: .dinner) > 0,
            addedAt: addedAt,
            sources: [source]
        )
    }
}
