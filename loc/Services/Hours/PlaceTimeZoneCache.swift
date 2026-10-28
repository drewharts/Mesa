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

    /// Known zones at known spots (from any reverse geocode), used for places without their own.
    private var anchors: [(lat: Double, lon: Double, tz: TimeZone)] = []
    private var coordinates: [String: (lat: Double, lon: Double)] = [:]
    private static let anchorRadiusKm = 150.0

    /// Place id -> its zone; else the zone of a geocoded spot within ~150 km; else the device zone.
    /// (The device zone alone is wrong when travelling with the phone clock on home time.)
    func timeZone(for placeId: String) -> TimeZone {
        let key = placeId.lowercased()
        lock.lock(); defer { lock.unlock() }
        if let tz = zones[key] { return tz }
        if let c = coordinates[key], let tz = Self.nearest(anchors, lat: c.lat, lon: c.lon) { return tz }
        return .current
    }

    /// Records where a place is so a nearby anchor's zone can be used for it.
    func registerCoordinate(placeId: String, latitude: Double, longitude: Double) {
        lock.lock(); coordinates[placeId.lowercased()] = (latitude, longitude); lock.unlock()
    }

    /// Records the zone at a spot (e.g. the user's location or any geocoded place).
    func addAnchor(latitude: Double, longitude: Double, timeZone: TimeZone) {
        lock.lock(); defer { lock.unlock() }
        if anchors.contains(where: { Self.km($0.lat, $0.lon, latitude, longitude) < 20 && $0.tz == timeZone }) { return }
        anchors.append((latitude, longitude, timeZone))
        if anchors.count > 200 { anchors.removeFirst(anchors.count - 200) }
    }

    private static func nearest(_ anchors: [(lat: Double, lon: Double, tz: TimeZone)], lat: Double, lon: Double) -> TimeZone? {
        var best: (Double, TimeZone)?
        for a in anchors {
            let d = km(a.lat, a.lon, lat, lon)
            if d <= anchorRadiusKm, best == nil || d < best!.0 { best = (d, a.tz) }
        }
        return best?.1
    }

    private static func km(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
        let r = 6371.0, p = Double.pi / 180
        let a = 0.5 - cos((lat2 - lat1) * p) / 2 + cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2
        return 2 * r * asin(sqrt(max(0, a)))
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
