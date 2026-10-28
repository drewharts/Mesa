//
//  PlaceHoursStore.swift
//  loc
//
//  Open/closed status for places shown in tiles and on map pins, computed from the hours we already
//  store on `places.open_hours` (no Google Places calls). Ids are batched into one Supabase query per
//  ~80 places and cached for the session. Time zones come from the reverse geocode that list tiles
//  already do; until known, the device time zone is used. A minute tick keeps statuses current.
//

import Foundation
import Combine

@MainActor
final class PlaceHoursStore: ObservableObject {
    static let shared = PlaceHoursStore()

    /// lowercased place id -> parsed hours (missing = unknown / not fetched).
    @Published private(set) var hours: [String: PlaceHours] = [:]
    /// Bumped every minute so observers re-evaluate.
    @Published private(set) var tick = Date()

    private var requested = Set<String>()
    private var pending = Set<String>()
    private var flushTask: Task<Void, Never>?
    private var timer: AnyCancellable?

    private init() {
        timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
            .sink { [weak self] date in self?.tick = date }
    }

    // MARK: - Reading

    func timeZone(for placeId: String) -> TimeZone {
        PlaceTimeZoneCache.shared.timeZone(for: placeId)
    }

    /// Current state, or nil when hours are unknown.
    func state(for placeId: String) -> PlaceHours.State? {
        let key = placeId.lowercased()
        guard let h = hours[key] else { return nil }
        _ = tick
        return h.state(at: Date(), timeZone: timeZone(for: key))
    }

    func changeText(for placeId: String) -> String? {
        guard let s = state(for: placeId) else { return nil }
        return PlaceHours.changeText(for: s, timeZone: timeZone(for: placeId))
    }

    // MARK: - Writing

    func setTimeZone(_ tz: TimeZone, for placeId: String) {
        let key = placeId.lowercased()
        if PlaceTimeZoneCache.shared.set(tz, for: key), hours[key] != nil { tick = Date() }
    }

    /// Seeds hours already loaded elsewhere (e.g. the detail view's DetailPlace).
    func seed(placeId: String, weekdayText: [String]?) {
        guard let weekdayText, let parsed = PlaceHours(weekdayText: weekdayText) else { return }
        let key = placeId.lowercased()
        requested.insert(key)
        if hours[key] != parsed { hours[key] = parsed }
    }

    /// Queues ids for a batched fetch. Safe to call from view bodies (work is deferred).
    func prefetch(_ placeIds: [String]) {
        let missing = placeIds.map { $0.lowercased() }.filter { !requested.contains($0) }
        guard !missing.isEmpty else { return }
        requested.formUnion(missing)
        pending.formUnion(missing)
        guard flushTask == nil else { return }
        flushTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 150_000_000)
            await self?.flush()
        }
    }

    private func flush() async {
        let ids = Array(pending)
        pending.removeAll()
        flushTask = nil
        guard !ids.isEmpty else { return }
        do {
            let fetched = try await PlaceListService.shared.fetchPlaceHours(placeIds: ids)
            var merged = hours
            for (key, lines) in fetched {
                if let parsed = PlaceHours(weekdayText: lines) { merged[key] = parsed }
            }
            hours = merged
        } catch {
            requested.subtract(ids) // retry next time
        }
    }
}
