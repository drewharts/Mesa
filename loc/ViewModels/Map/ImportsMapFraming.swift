//
//  ImportsMapFraming.swift
//  loc
//
//  Single Responsibility: Picks a sensible initial map region for the user's imports sheet.
//  Imports can be spread across cities and continents, so a global bounding box often centers
//  on empty space. Instead: frame nearby imports (plus the user) when there are any, else the
//  densest cluster of imports, else the user, and never default wider than a metro area.
//

import CoreLocation
import MapKit

/// Pure helpers that choose which coordinates to frame and the region that frames them.
enum ImportsMapFraming {
    /// Radius treated as "near the user" (20 miles).
    static let nearbyRadiusMeters: CLLocationDistance = 32_187
    /// Radius used to group imports into a cluster (about a metro area).
    static let clusterRadiusMeters: CLLocationDistance = 40_000
    /// Smallest default span in degrees (about a neighborhood).
    static let minSpanDegrees: CLLocationDegrees = 0.03
    /// Largest default span in degrees (about a metro area).
    static let maxSpanDegrees: CLLocationDegrees = 0.6
    /// Padding applied around the framed coordinates.
    static let padding: Double = 1.3

    /// Returns the region to show when the sheet opens; nil when there is nothing to frame.
    /// - Parameters:
    ///   - recent: The user's imports, newest first (used for clustering).
    ///   - nearby: Imports already known to be within the nearby radius (may overlap `recent`).
    ///   - user: The user's location, if known.
    static func region(
        recent: [CLLocationCoordinate2D],
        nearby: [CLLocationCoordinate2D],
        user: CLLocationCoordinate2D?
    ) -> MKCoordinateRegion? {
        region(containing: focusCoordinates(recent: recent, nearby: nearby, user: user))
    }

    /// Chooses what to frame: nearby imports plus the user, else the densest cluster, else the user.
    static func focusCoordinates(
        recent: [CLLocationCoordinate2D],
        nearby: [CLLocationCoordinate2D],
        user: CLLocationCoordinate2D?
    ) -> [CLLocationCoordinate2D] {
        let recent = recent.filter(isValid)
        if let user, isValid(user) {
            let userLocation = CLLocation(latitude: user.latitude, longitude: user.longitude)
            let close = (nearby.filter(isValid) + recent).filter {
                distance(userLocation, $0) <= nearbyRadiusMeters
            }
            if !close.isEmpty { return close + [user] }
        }
        let cluster = densestCluster(recent)
        if !cluster.isEmpty { return cluster }
        if let user, isValid(user) { return [user] }
        return []
    }

    /// Returns the members of the largest cluster (ties go to the most recent seed, i.e. lowest index).
    static func densestCluster(_ coordinates: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        let locations = coordinates.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
        var best: [CLLocationCoordinate2D] = []
        for seed in locations {
            let members = coordinates.filter { distance(seed, $0) <= clusterRadiusMeters }
            if members.count > best.count { best = members }
        }
        return best
    }

    /// Returns a padded region around the coordinates, clamped between neighborhood and metro scale.
    static func region(containing coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion? {
        guard let first = coordinates.first else { return nil }
        var minLat = first.latitude, maxLat = first.latitude
        var minLon = first.longitude, maxLon = first.longitude
        for c in coordinates {
            minLat = min(minLat, c.latitude); maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude); maxLon = max(maxLon, c.longitude)
        }
        let latSpan = clamp((maxLat - minLat) * padding)
        let lonSpan = clamp((maxLon - minLon) * padding)
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
            span: MKCoordinateSpan(latitudeDelta: latSpan, longitudeDelta: lonSpan)
        )
    }

    // MARK: - Private

    /// Clamps a span between the neighborhood minimum and metro maximum.
    private static func clamp(_ span: CLLocationDegrees) -> CLLocationDegrees {
        min(max(span, minSpanDegrees), maxSpanDegrees)
    }

    /// Returns whether a coordinate is real (in range and not the 0,0 placeholder).
    private static func isValid(_ c: CLLocationCoordinate2D) -> Bool {
        abs(c.latitude) <= 90 && abs(c.longitude) <= 180 && !(c.latitude == 0 && c.longitude == 0)
    }

    /// Returns the distance in meters from a location to a coordinate.
    private static func distance(_ from: CLLocation, _ to: CLLocationCoordinate2D) -> CLLocationDistance {
        from.distance(from: CLLocation(latitude: to.latitude, longitude: to.longitude))
    }
}
