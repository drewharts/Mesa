//
//  MapCameraSettleGate.swift
//  loc
//
//  Filters camera-settle notifications so the map only reports a settle to the rest of the app
//  when the viewport actually changed, instead of on every idle (including no-op settles that
//  follow programmatic animations or tiny jitter at the end of a pinch).
//

import MapKit

struct MapCameraSettleGate {
    /// Fraction of the last reported span that the center/span must change by to count as new.
    private let tolerance: Double
    private var lastReported: MKCoordinateRegion?

    init(tolerance: Double = 0.02) {
        self.tolerance = tolerance
    }

    /// Returns true (and remembers the region) when it differs meaningfully from the last reported one.
    mutating func shouldReport(_ region: MKCoordinateRegion) -> Bool {
        guard let last = lastReported else {
            lastReported = region
            return true
        }
        let latSpan = max(last.span.latitudeDelta, .leastNormalMagnitude)
        let lngSpan = max(last.span.longitudeDelta, .leastNormalMagnitude)
        let moved = abs(region.center.latitude - last.center.latitude) > latSpan * tolerance
            || abs(region.center.longitude - last.center.longitude) > lngSpan * tolerance
        let zoomed = abs(region.span.latitudeDelta - last.span.latitudeDelta) > latSpan * tolerance
            || abs(region.span.longitudeDelta - last.span.longitudeDelta) > lngSpan * tolerance
        guard moved || zoomed else { return false }
        lastReported = region
        return true
    }
}
