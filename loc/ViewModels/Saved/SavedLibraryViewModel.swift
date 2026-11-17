//
//  SavedLibraryViewModel.swift
//  loc
//
//  Loads the places the user already has (lists, favorites, my places, imports) with read-only
//  queries, then sorts them on device with SavedLibraryBuilder into one entry per city
//  (plus the smart groups). Writes nothing.
//

import CoreLocation
import Foundation

@MainActor
final class SavedLibraryViewModel: ObservableObject {
    @Published private(set) var library: SavedLibrary = .empty
    @Published private(set) var isLoading = false
    @Published private(set) var loadError: String?

    private var hasLoaded = false

    // MARK: - Derived

    /// One entry per city, biggest first; the "Other places" bucket is last.
    var cities: [SavedCityGroup] { library.cities }

    /// "20 Restaurants · 8 Bars · 5 Coffee & Sweets": the three biggest types in a city.
    func summary(for city: SavedCityGroup) -> String {
        let top = city.typeCounts.sorted { $0.count > $1.count }.prefix(3)
        return top.map { "\($0.count) \($0.type.title)" }.joined(separator: " · ")
    }

    /// How a smart group is ordered when opened: "Saved this week" is newest first, the rest nearest first.
    func ordering(for group: SavedSmartGroup) -> SavedCityDetailViewModel.Ordering {
        group.kind == .thisWeek ? .recent : .nearest
    }

    // MARK: - Loading

    /// Loads the library once; later calls are no-ops (use `load` to refresh).
    func loadIfNeeded(userId: String?, location: CLLocation?) async {
        guard !hasLoaded else { return }
        await load(userId: userId, location: location)
    }

    /// Reads and sorts the user's places; keeps the previous library when a refresh fails.
    func load(userId: String?, location: CLLocation?) async {
        guard let userId, !userId.isEmpty else { return }
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            let inputs = try await SavedLibraryDataSource.fetchInputs(userId: userId)
            let userLocation = location.map { (lat: $0.coordinate.latitude, lon: $0.coordinate.longitude) }
            library = await Task.detached(priority: .userInitiated) {
                SavedLibraryBuilder.build(inputs, userLocation: userLocation)
            }.value
            hasLoaded = true
        } catch {
            loadError = "Couldn't load your places. Pull to retry."
        }
    }
}
