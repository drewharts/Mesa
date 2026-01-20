//
//  ViewportBoundsHelper.swift
//  loc
//
//  Provides adaptive viewport bounds for keyword searches
//  Ensures search area is neither too small (no results) nor too large (too many results)
//

import Foundation
import MapKit
import CoreLocation

/// Helper for computing adaptive search bounds for keyword queries
struct ViewportBoundsHelper {

    // MARK: - Configuration

    /// Minimum search span in degrees (~3.5 miles latitude)
    /// Used when user is zoomed in very close
    static let minimumSpanDegrees: Double = 0.05

    /// Maximum search span in degrees (~10 miles latitude)
    /// Used when user is zoomed out very far
    static let maximumSpanDegrees: Double = 0.15

    /// Default search span when no map region is available
    static let defaultSpanDegrees: Double = 0.1

    // MARK: - Bounds Tuple Type

    typealias Bounds = (northLat: Double, southLat: Double, eastLng: Double, westLng: Double)

    // MARK: - Public Methods

    /// Computes adaptive search bounds from a map region
    /// - Parameters:
    ///   - region: Optional map region (current viewport)
    ///   - fallbackLocation: Optional fallback location (user's current location) when region is nil
    /// - Returns: Normalized bounds within min/max thresholds, or nil if no location available
    static func getAdaptiveBounds(
        from region: MKCoordinateRegion?,
        fallbackLocation: CLLocationCoordinate2D?
    ) -> Bounds? {
        // Determine center and span
        let center: CLLocationCoordinate2D
        let currentSpan: Double

        if let region = region {
            center = region.center
            // Use the larger of lat/lng span for consistency
            currentSpan = max(region.span.latitudeDelta, region.span.longitudeDelta)
        } else if let fallback = fallbackLocation {
            // No map region available - use fallback location with default span
            center = fallback
            currentSpan = defaultSpanDegrees
        } else {
            // No location available at all
            return nil
        }

        // Normalize the span to be within min/max bounds
        let normalizedSpan = normalizeSpan(currentSpan)

        // Calculate bounds from center and normalized span
        return (
            northLat: center.latitude + (normalizedSpan / 2),
            southLat: center.latitude - (normalizedSpan / 2),
            eastLng: center.longitude + (normalizedSpan / 2),
            westLng: center.longitude - (normalizedSpan / 2)
        )
    }

    /// Computes adaptive search bounds from just a location coordinate
    /// Uses default span since no viewport information is available
    /// - Parameter location: The center location for the search
    /// - Returns: Bounds centered on the location with default span
    static func getBoundsFromLocation(_ location: CLLocationCoordinate2D) -> Bounds {
        let span = defaultSpanDegrees
        return (
            northLat: location.latitude + (span / 2),
            southLat: location.latitude - (span / 2),
            eastLng: location.longitude + (span / 2),
            westLng: location.longitude - (span / 2)
        )
    }

    // MARK: - Private Helpers

    /// Clamps the span to be within minimum and maximum thresholds
    private static func normalizeSpan(_ span: Double) -> Double {
        if span < minimumSpanDegrees {
            return minimumSpanDegrees
        } else if span > maximumSpanDegrees {
            return maximumSpanDegrees
        }
        return span
    }
}
