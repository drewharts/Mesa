//
//  PlaceTimeZoneCache.swift
//  loc
//
//  Thread-safe place id -> time zone cache (persisted). Filled from reverse geocodes; read by
//  open/closed evaluation from any context. Falls back to the device time zone.
//

import Foundation

final class PlaceTimeZoneCache: @unchecked Sendable {
    static let shared = PlaceTimeZoneCache()

    private let lock = NSLock()
    private var zones: [String: TimeZone]
    private static let defaultsKey = "place_time_zones_v1"

    private init() {
        let saved = (UserDefaults.standard.dictionary(forKey: Self.defaultsKey) as? [String: String]) ?? [:]
        zones = saved.compactMapValues { TimeZone(identifier: $0) }
    }

    func timeZone(for placeId: String) -> TimeZone {
        lock.lock(); defer { lock.unlock() }
        return zones[placeId.lowercased()] ?? .current
    }

    /// Returns true when the stored value changed.
    @discardableResult
    func set(_ tz: TimeZone, for placeId: String) -> Bool {
        let key = placeId.lowercased()
        lock.lock()
        guard zones[key] != tz else { lock.unlock(); return false }
        zones[key] = tz
        let snapshot = zones.count <= 5000 ? zones.mapValues { $0.identifier } : nil
        lock.unlock()
        if let snapshot { UserDefaults.standard.set(snapshot, forKey: Self.defaultsKey) }
        return true
    }
}
