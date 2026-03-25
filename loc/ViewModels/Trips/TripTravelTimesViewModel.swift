//
//  TripTravelTimesViewModel.swift
//  loc
//
//  Child ViewModel: calculates and caches travel times between consecutive trip places
//

import Foundation
import CoreLocation

@MainActor
class TripTravelTimesViewModel: ObservableObject {

    // MARK: - Published State

    @Published var segments: [String: TripTravelTimeSegment] = [:]

    // MARK: - Dependencies

    private let mapKitService = MapKitService.shared

    // MARK: - Task Tracking

    /// In-flight tasks per day index, cancelled on recalculation to avoid stale results.
    private var dayTasks: [Int: Task<Void, Never>] = [:]

    // MARK: - Transport Types

    private let transportTypes: [MapKitService.TransportType] = [.automobile, .walking, .transit]

    // MARK: - Recalculate All Days

    /// Iterates all days, computes needed pairs, and fetches only missing segments.
    func recalculate(dayPlaces: [Int: [TripDayPlace]]) {
        for (dayIndex, places) in dayPlaces {
            recalculateDay(dayIndex: dayIndex, places: places)
        }
    }

    // MARK: - Recalculate Single Day

    /// Recalculates travel times for a single day, cancelling any in-flight task for that day.
    func recalculateDay(dayIndex: Int, places: [TripDayPlace]) {
        dayTasks[dayIndex]?.cancel()

        let pairs = buildPairsAndCacheCoordinates(from: places)
        guard !pairs.isEmpty else { return }

        // Filter to only pairs not already cached
        let needed = pairs.filter { segments[$0.cacheKey] == nil }
        guard !needed.isEmpty else { return }

        // Mark loading state for new segments
        for pair in needed {
            segments[pair.cacheKey] = pair
        }

        dayTasks[dayIndex] = Task {
            await fetchSegmentsSequentially(needed)
        }
    }

    // MARK: - Lookup

    /// Returns the cached segment for a given place pair.
    func segment(from fromId: String, to toId: String) -> TripTravelTimeSegment? {
        segments["\(fromId)->\(toId)"]
    }

    // MARK: - Formatting

    /// Formats a travel time interval into a user-friendly string.
    static func formattedTime(from timeInterval: TimeInterval) -> String {
        let minutes = timeInterval / 60.0
        return minutes > 60 ? "60+ min" : String(format: "%.0f min", minutes)
    }

    // MARK: - Private Helpers

    /// Builds loading-state segment pairs from consecutive places in a day.
    private func buildPairs(from places: [TripDayPlace]) -> [TripTravelTimeSegment] {
        guard places.count >= 2 else { return [] }

        var pairs: [TripTravelTimeSegment] = []
        for i in 0..<(places.count - 1) {
            let from = places[i]
            let to = places[i + 1]

            let hasFailed = from.placeLatitude == nil || from.placeLongitude == nil
                || to.placeLatitude == nil || to.placeLongitude == nil

            pairs.append(TripTravelTimeSegment(
                fromPlaceId: from.placeId,
                toPlaceId: to.placeId,
                travelTimes: [:],
                isLoading: !hasFailed,
                hasFailed: hasFailed
            ))
        }
        return pairs
    }

    /// Fetches travel times for segments sequentially to avoid MapKit rate limiting.
    private func fetchSegmentsSequentially(_ pairs: [TripTravelTimeSegment]) async {
        for pair in pairs {
            guard !Task.isCancelled else { return }

            if pair.hasFailed {
                continue // Already marked as failed in buildPairs
            }

            // Look up coordinates from the segment — we need to find them from the pair's place IDs
            // The pairs were built from places that have coordinates (hasFailed = false)
            guard let origin = coordinateForPlace(pair.fromPlaceId),
                  let destination = coordinateForPlace(pair.toPlaceId) else {
                segments[pair.cacheKey]?.isLoading = false
                segments[pair.cacheKey]?.hasFailed = true
                continue
            }

            let result = await calculateTravelTimes(from: origin, to: destination)

            guard !Task.isCancelled else { return }

            if let times = result {
                segments[pair.cacheKey]?.travelTimes = times
                segments[pair.cacheKey]?.isLoading = false
            } else {
                segments[pair.cacheKey]?.isLoading = false
                segments[pair.cacheKey]?.hasFailed = true
            }
        }
    }

    /// Finds coordinates for a place ID by scanning all cached segments' source data.
    /// Falls back to nil if the place has no coordinates.
    private func coordinateForPlace(_ placeId: String) -> CLLocationCoordinate2D? {
        // We store coordinates in a local lookup built during recalculate
        return coordinateCache[placeId]
    }

    /// Local coordinate cache populated during buildPairs to avoid re-scanning.
    private var coordinateCache: [String: CLLocationCoordinate2D] = [:]

    /// Builds pairs and caches coordinates for place lookups during fetching.
    private func buildPairsAndCacheCoordinates(from places: [TripDayPlace]) -> [TripTravelTimeSegment] {
        for place in places {
            if let lat = place.placeLatitude, let lng = place.placeLongitude {
                coordinateCache[place.placeId] = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            }
        }
        return buildPairs(from: places)
    }

    /// Wraps the callback-based MapKitService with async/await.
    private func calculateTravelTimes(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async -> [MapKitService.TransportType: TimeInterval]? {
        await withCheckedContinuation { continuation in
            mapKitService.calculateTravelTimes(
                from: origin,
                to: destination,
                transportTypes: transportTypes
            ) { results, _ in
                continuation.resume(returning: results)
            }
        }
    }
}
