//
//  TripRouteService.swift
//  loc
//
//  Computes and caches walking-route geometry between consecutive trip stops.
//  Shared by the main (Google) map trip overlay and TripMapView.
//

import Foundation
import MapKit

/// A drawable line between two consecutive stops in a trip day.
struct TripRouteSegment: Identifiable, Equatable {
    let id: String
    let dayIndex: Int
    let coordinates: [CLLocationCoordinate2D]
    /// True when the line follows a MapKit walking route; false for the straight-line fallback.
    let isWalkingRoute: Bool
    /// True when the leg ends at a visited stop (already walked) — drawn muted.
    var isCompleted: Bool = false

    static func == (lhs: TripRouteSegment, rhs: TripRouteSegment) -> Bool {
        lhs.id == rhs.id
            && lhs.isWalkingRoute == rhs.isWalkingRoute
            && lhs.isCompleted == rhs.isCompleted
            && lhs.coordinates.count == rhs.coordinates.count
    }
}

@MainActor
final class TripRouteService {
    static let shared = TripRouteService()

    /// Walking route geometry per coordinate pair, cached for the app session.
    private var walkingRouteCache: [String: [CLLocationCoordinate2D]] = [:]
    /// Pairs whose directions request failed this session (draw straight lines, don't retry).
    private var failedRouteKeys: Set<String> = []
    /// Pairs currently being fetched (avoid duplicate requests from two callers).
    private var inFlightKeys: Set<String> = []

    /// Max walking-direction requests per call (MapKit throttles ~50/min).
    private let maxRequestsPerLoad = 30
    /// Pairs farther apart than this skip walking directions and draw a straight line.
    private let maxWalkingDistanceMeters: CLLocationDistance = 8_000

    private init() {}

    private func routeKey(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> String {
        String(format: "%.5f,%.5f->%.5f,%.5f", a.latitude, a.longitude, b.latitude, b.longitude)
    }

    /// Consecutive stop pairs per day, in pin order (stopNumber).
    private func pairs(for annotations: [TripMapAnnotation]) -> [(dayIndex: Int, from: TripMapAnnotation, to: TripMapAnnotation)] {
        let grouped = Dictionary(grouping: annotations, by: { $0.dayIndex })
        var result: [(dayIndex: Int, from: TripMapAnnotation, to: TripMapAnnotation)] = []
        for dayIndex in grouped.keys.sorted() {
            let stops = (grouped[dayIndex] ?? []).sorted { $0.stopNumber < $1.stopNumber }
            guard stops.count >= 2 else { continue }
            for i in 0..<(stops.count - 1) {
                result.append((dayIndex: dayIndex, from: stops[i], to: stops[i + 1]))
            }
        }
        return result
    }

    /// Lines to draw for the given annotations: cached walking route, else a straight line.
    func segments(for annotations: [TripMapAnnotation]) -> [TripRouteSegment] {
        pairs(for: annotations).map { pair in
            let id = "\(pair.from.id)->\(pair.to.id)"
            let key = routeKey(pair.from.coordinate, pair.to.coordinate)
            if let coords = walkingRouteCache[key], coords.count >= 2 {
                return TripRouteSegment(id: id, dayIndex: pair.dayIndex, coordinates: coords,
                                        isWalkingRoute: true, isCompleted: pair.to.isVisited)
            }
            return TripRouteSegment(
                id: id,
                dayIndex: pair.dayIndex,
                coordinates: [pair.from.coordinate, pair.to.coordinate],
                isWalkingRoute: false,
                isCompleted: pair.to.isVisited
            )
        }
    }

    /// Fetches missing walking routes one at a time; calls `onProgress` after each new route.
    func loadMissingRoutes(for annotations: [TripMapAnnotation], onProgress: @escaping () -> Void) async {
        var needed: [(CLLocationCoordinate2D, CLLocationCoordinate2D)] = []
        for pair in pairs(for: annotations) {
            let a = pair.from.coordinate, b = pair.to.coordinate
            let key = routeKey(a, b)
            guard walkingRouteCache[key] == nil,
                  !failedRouteKeys.contains(key),
                  !inFlightKeys.contains(key) else { continue }
            let distance = CLLocation(latitude: a.latitude, longitude: a.longitude)
                .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
            guard distance <= maxWalkingDistanceMeters else { continue }
            needed.append((a, b))
        }

        for (a, b) in needed.prefix(maxRequestsPerLoad) {
            guard !Task.isCancelled else { return }
            let key = routeKey(a, b)
            guard walkingRouteCache[key] == nil, !inFlightKeys.contains(key) else { continue }
            inFlightKeys.insert(key)
            let coords = await Self.fetchWalkingRoute(from: a, to: b)
            inFlightKeys.remove(key)
            if let coords {
                walkingRouteCache[key] = coords
                onProgress()
            } else {
                failedRouteKeys.insert(key)
            }
        }
    }

    /// Requests a walking route from MapKit and returns its polyline coordinates.
    private static func fetchWalkingRoute(
        from a: CLLocationCoordinate2D,
        to b: CLLocationCoordinate2D
    ) async -> [CLLocationCoordinate2D]? {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: a))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: b))
        request.transportType = .walking
        request.requestsAlternateRoutes = false
        do {
            let response = try await MKDirections(request: request).calculate()
            guard let polyline = response.routes.first?.polyline, polyline.pointCount >= 2 else { return nil }
            var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: polyline.pointCount)
            polyline.getCoordinates(&coords, range: NSRange(location: 0, length: polyline.pointCount))
            return coords
        } catch {
            return nil
        }
    }
}
