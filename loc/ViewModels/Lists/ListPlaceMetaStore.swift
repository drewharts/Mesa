//
//  ListPlaceMetaStore.swift
//  loc
//
//  Supplies the "neighborhood" part of a list row's category line. Neighborhoods are not stored
//  in the database, so this store shows the city right away (one batched query) and refines it to
//  the neighborhood by reverse-geocoding visible rows one at a time. Results are persisted so
//  reopening a list is instant and the geocoder rate limit is rarely touched.
//

import Foundation

@MainActor
final class ListPlaceMetaStore: ObservableObject {
    static let shared = ListPlaceMetaStore()

    // MARK: - Published State

    /// lowercased place id -> city.
    @Published private(set) var cities: [String: String] = [:]
    /// lowercased place id -> neighborhood ("" means we looked and found none).
    @Published private(set) var neighborhoods: [String: String]

    // MARK: - Private State

    private struct PendingLookup {
        let key: String
        let latitude: Double
        let longitude: Double
    }

    private static let defaultsKey = "list_place_neighborhoods_v1"
    private static let maxPersistedEntries = 3000

    private var requestedCityKeys = Set<String>()
    private var queuedKeys = Set<String>()
    private var queue: [PendingLookup] = []
    private var worker: Task<Void, Never>?
    private var persistTask: Task<Void, Never>?

    /// Most lookups kept waiting. Rows flung past while scrolling fast would otherwise queue hundreds of
    /// geocodes (minutes of work for rows no longer on screen); the oldest are dropped first.
    static let maxQueuedLookups = 20
    /// Longest the persisted neighborhoods may lag behind memory.
    private static let persistDelayNanoseconds: UInt64 = 3_000_000_000

    private init() {
        neighborhoods = (UserDefaults.standard.dictionary(forKey: Self.defaultsKey) as? [String: String]) ?? [:]
    }

    // MARK: - Reading

    /// The location line for a place: its neighborhood when known, otherwise its city.
    func location(for placeId: String) -> String? {
        let key = placeId.lowercased()
        if let neighborhood = neighborhoods[key], !neighborhood.isEmpty { return neighborhood }
        return cities[key]
    }

    // MARK: - Loading

    /// Loads cities for any places we have not asked about yet.
    func prefetchCities(for places: [LightweightPlace]) {
        let missing = places
            .map { $0.place_id.lowercased() }
            .filter { !requestedCityKeys.contains($0) && cities[$0] == nil }
        guard !missing.isEmpty else { return }
        requestedCityKeys.formUnion(missing)

        Task { [weak self] in
            do {
                let fetched = try await PlaceListService.shared.fetchPlaceCities(placeIds: missing)
                self?.cities.merge(fetched) { _, new in new }
            } catch {
                // Allow a retry the next time these rows appear.
                self?.requestedCityKeys.subtract(missing)
            }
        }
    }

    /// Queues a neighborhood lookup for a row that became visible.
    func requestNeighborhood(for place: LightweightPlace) {
        let key = place.place_id.lowercased()
        guard neighborhoods[key] == nil, !queuedKeys.contains(key),
              let latitude = place.latitude, let longitude = place.longitude else { return }
        queuedKeys.insert(key)
        queue.append(PendingLookup(key: key, latitude: latitude, longitude: longitude))
        trimQueue()
        startWorkerIfNeeded()
    }

    // MARK: - Worker

    private func startWorkerIfNeeded() {
        guard worker == nil else { return }
        worker = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                guard let next = self.dequeue() else { break }
                let outcome = await NeighborhoodGeocodingService.shared.neighborhood(
                    latitude: next.latitude,
                    longitude: next.longitude
                )
                self.record(outcome, for: next.key)
                if let tz = NeighborhoodGeocodingService.shared.lastTimeZone {
                    PlaceTimeZoneCache.shared.addAnchor(latitude: next.latitude, longitude: next.longitude, timeZone: tz)
                    PlaceHoursStore.shared.setTimeZone(tz, for: next.key)
                }
                // Stay under the geocoder's rate limit.
                try? await Task.sleep(nanoseconds: 1_300_000_000)
            }
            self?.worker = nil
        }
    }

    /// Takes the most recently requested lookup: the rows the user is looking at now beat ones already scrolled past.
    private func dequeue() -> PendingLookup? {
        queue.popLast()
    }

    /// Drops the oldest queued lookups beyond the cap, letting those rows re-request if they appear again.
    private func trimQueue() {
        while queue.count > Self.maxQueuedLookups {
            queuedKeys.remove(queue.removeFirst().key)
        }
    }

    private func record(_ outcome: NeighborhoodGeocodingService.Outcome, for key: String) {
        queuedKeys.remove(key)
        switch outcome {
        case .found(let name):
            neighborhoods[key] = name
            persist()
        case .notFound:
            neighborhoods[key] = ""
            persist()
        case .unavailable:
            break
        }
    }

    /// Schedules one coalesced write of the neighborhoods; rewriting the whole dictionary after every
    /// lookup blocked the main thread while scrolling.
    private func persist() {
        guard persistTask == nil else { return }
        persistTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.persistDelayNanoseconds)
            self?.writeNeighborhoods()
        }
    }

    /// Trims the stored neighborhoods to the cap and saves them to UserDefaults.
    private func writeNeighborhoods() {
        persistTask = nil
        if neighborhoods.count > Self.maxPersistedEntries {
            let overflow = neighborhoods.count - Self.maxPersistedEntries
            for key in neighborhoods.keys.prefix(overflow) { neighborhoods.removeValue(forKey: key) }
        }
        UserDefaults.standard.set(neighborhoods, forKey: Self.defaultsKey)
    }
}
