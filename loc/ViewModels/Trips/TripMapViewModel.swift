//
//  TripMapViewModel.swift
//  loc
//
//  Map state and logic for the trip map view
//

import SwiftUI
import MapKit

@MainActor
class TripMapViewModel: ObservableObject {
    // MARK: - Day Color Palette

    /// 8-color palette that cycles for trips with more than 8 days.
    nonisolated static let dayColors: [Color] = [
        Color(red: 0.36, green: 0.54, blue: 0.90),
        Color(red: 0.90, green: 0.42, blue: 0.42),
        Color(red: 0.30, green: 0.78, blue: 0.55),
        Color(red: 0.95, green: 0.68, blue: 0.30),
        Color(red: 0.62, green: 0.44, blue: 0.85),
        Color(red: 0.20, green: 0.75, blue: 0.80),
        Color(red: 0.90, green: 0.55, blue: 0.72),
        Color(red: 0.55, green: 0.70, blue: 0.35),
    ]

    // MARK: - Published State

    @Published var mapPosition: MapCameraPosition = .automatic
    @Published var selectedDayFilter: Int?
    @Published var selectedAnnotationId: String?
    @Published var selectedPlaceIdForDetail: String?

    // MARK: - Input Data

    let trip: Trip
    let dayPlaces: [Int: [TripDayPlace]]
    let dayIndices: [Int]

    // MARK: - Initialization

    init(trip: Trip, dayPlaces: [Int: [TripDayPlace]], dayIndices: [Int]) {
        self.trip = trip
        self.dayPlaces = dayPlaces
        self.dayIndices = dayIndices
    }

    // MARK: - Day Colors

    /// Returns the base color for a given day index (cycles through palette).
    nonisolated static func colorForDay(_ dayIndex: Int) -> Color {
        dayColors[dayIndex % dayColors.count]
    }

    /// Returns a brightness-adjusted color for a stop within a day.
    nonisolated static func colorForStop(dayIndex: Int, stopIndex: Int, totalStops: Int) -> Color {
        let baseColor = colorForDay(dayIndex)
        guard totalStops > 1 else { return baseColor }

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        UIColor(baseColor).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        let adjustedBrightness = brightness * (1.0 - 0.4 * CGFloat(stopIndex) / CGFloat(max(totalStops - 1, 1)))
        return Color(hue: Double(hue), saturation: Double(saturation), brightness: Double(adjustedBrightness))
    }

    // MARK: - Annotations

    /// Builds display-ready annotations filtered by the current day filter.
    var annotations: [TripMapAnnotation] {
        Self.buildAnnotations(
            dayPlaces: dayPlaces,
            dayIndices: dayIndices,
            selectedDayFilter: selectedDayFilter
        )
    }

    /// Builds display-ready annotations from day places data.
    nonisolated static func buildAnnotations(
        dayPlaces: [Int: [TripDayPlace]],
        dayIndices: [Int],
        selectedDayFilter: Int? = nil
    ) -> [TripMapAnnotation] {
        var result: [TripMapAnnotation] = []

        let indicesToShow: [Int]
        if let filter = selectedDayFilter {
            indicesToShow = [filter]
        } else {
            indicesToShow = dayIndices
        }

        for dayIndex in indicesToShow {
            let places = dayPlaces[dayIndex] ?? []
            let placesWithCoords = places.filter { $0.placeLatitude != nil && $0.placeLongitude != nil }
            let totalStops = placesWithCoords.count

            for (stopIndex, place) in placesWithCoords.enumerated() {
                guard let lat = place.placeLatitude, let lon = place.placeLongitude else { continue }
                let color = colorForStop(dayIndex: dayIndex, stopIndex: stopIndex, totalStops: totalStops)
                let annotation = TripMapAnnotation(
                    id: place.id,
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    placeName: place.placeName ?? "Unknown Place",
                    placeAddress: place.placeAddress,
                    dayIndex: dayIndex,
                    stopNumber: stopIndex + 1,
                    totalStopsInDay: totalStops,
                    color: color,
                    placeId: place.placeId,
                    placeType: place.placeType
                )
                result.append(annotation)
            }
        }

        return result
    }

    // MARK: - Routes

    /// A drawable line between two consecutive stops in a day.
    struct RouteSegment: Identifiable {
        let id: String
        let dayIndex: Int
        let coordinates: [CLLocationCoordinate2D]
        /// True when the line follows a MapKit walking route; false for the straight-line fallback.
        let isWalkingRoute: Bool
    }

    /// Walking route geometry cached per stop pair for the app session, so reopening the map
    /// doesn't re-request directions. Key: "lat,lon->lat,lon".
    private static var walkingRouteCache: [String: [CLLocationCoordinate2D]] = [:]
    /// Pairs whose directions request failed this session (use straight lines, don't retry).
    private static var failedRouteKeys: Set<String> = []

    /// Bumped when new route geometry arrives so SwiftUI redraws.
    @Published private var routeRevision = 0
    private var routeTask: Task<Void, Never>?

    /// Max walking-direction requests per map open (MapKit throttles ~50/min).
    private let maxRouteRequests = 30
    /// Pairs farther apart than this skip walking directions and draw a straight line.
    private let maxWalkingDistanceMeters: CLLocationDistance = 8_000

    private static func routeKey(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> String {
        String(format: "%.5f,%.5f->%.5f,%.5f", a.latitude, a.longitude, b.latitude, b.longitude)
    }

    /// Consecutive stop pairs per visible day, in itinerary order (matching pin numbers).
    private var routePairs: [(dayIndex: Int, from: TripMapAnnotation, to: TripMapAnnotation)] {
        let grouped = Dictionary(grouping: annotations, by: \.dayIndex)
        var pairs: [(dayIndex: Int, from: TripMapAnnotation, to: TripMapAnnotation)] = []
        for dayIndex in grouped.keys.sorted() {
            let stops = (grouped[dayIndex] ?? []).sorted { $0.stopNumber < $1.stopNumber }
            guard stops.count >= 2 else { continue }
            for i in 0..<(stops.count - 1) {
                pairs.append((dayIndex: dayIndex, from: stops[i], to: stops[i + 1]))
            }
        }
        return pairs
    }

    /// Lines to draw: walking route when available, otherwise a straight line.
    var routeSegments: [RouteSegment] {
        _ = routeRevision
        return routePairs.map { pair in
            let key = Self.routeKey(pair.from.coordinate, pair.to.coordinate)
            if let coords = Self.walkingRouteCache[key], coords.count >= 2 {
                return RouteSegment(id: "\(pair.from.id)->\(pair.to.id)", dayIndex: pair.dayIndex,
                                    coordinates: coords, isWalkingRoute: true)
            }
            return RouteSegment(id: "\(pair.from.id)->\(pair.to.id)", dayIndex: pair.dayIndex,
                                coordinates: [pair.from.coordinate, pair.to.coordinate], isWalkingRoute: false)
        }
    }

    /// Fetches walking routes for all stop pairs (all days) that aren't cached yet, one at a time.
    func loadRoutes() {
        routeTask?.cancel()
        let allPairs = Self.buildAnnotations(dayPlaces: dayPlaces, dayIndices: dayIndices)
        let grouped = Dictionary(grouping: allPairs, by: \.dayIndex)
        var needed: [(CLLocationCoordinate2D, CLLocationCoordinate2D)] = []
        for dayIndex in grouped.keys.sorted() {
            let stops = (grouped[dayIndex] ?? []).sorted { $0.stopNumber < $1.stopNumber }
            guard stops.count >= 2 else { continue }
            for i in 0..<(stops.count - 1) {
                let a = stops[i].coordinate, b = stops[i + 1].coordinate
                let key = Self.routeKey(a, b)
                guard Self.walkingRouteCache[key] == nil, !Self.failedRouteKeys.contains(key) else { continue }
                let distance = CLLocation(latitude: a.latitude, longitude: a.longitude)
                    .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
                guard distance <= maxWalkingDistanceMeters else { continue }
                needed.append((a, b))
            }
        }
        guard !needed.isEmpty else { return }
        let batch = Array(needed.prefix(maxRouteRequests))

        routeTask = Task { @MainActor [weak self] in
            for (a, b) in batch {
                guard !Task.isCancelled else { return }
                let key = Self.routeKey(a, b)
                if let coords = await Self.fetchWalkingRoute(from: a, to: b) {
                    Self.walkingRouteCache[key] = coords
                    self?.routeRevision += 1
                } else {
                    Self.failedRouteKeys.insert(key)
                }
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
            var coords = [CLLocationCoordinate2D](
                repeating: kCLLocationCoordinate2DInvalid,
                count: polyline.pointCount
            )
            polyline.getCoordinates(&coords, range: NSRange(location: 0, length: polyline.pointCount))
            return coords
        } catch {
            return nil
        }
    }

    // MARK: - Camera

    /// Fits the map camera to show all current annotations with padding.
    func fitMapToAnnotations() {
        let coords = annotations.map(\.coordinate)
        guard !coords.isEmpty else { return }

        if coords.count == 1 {
            withAnimation(.easeInOut(duration: 0.5)) {
                mapPosition = .region(MKCoordinateRegion(
                    center: coords[0],
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                ))
            }
            return
        }

        let lats = coords.map(\.latitude)
        let lons = coords.map(\.longitude)
        let minLat = lats.min()!
        let maxLat = lats.max()!
        let minLon = lons.min()!
        let maxLon = lons.max()!

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.4 + 0.005,
            longitudeDelta: (maxLon - minLon) * 1.4 + 0.005
        )

        withAnimation(.easeInOut(duration: 0.5)) {
            mapPosition = .region(MKCoordinateRegion(center: center, span: span))
        }
    }

    // MARK: - Selection

    /// Selects an annotation by ID and animates the camera to it.
    func selectAnnotation(_ id: String) {
        selectedAnnotationId = id
        guard let annotation = annotations.first(where: { $0.id == id }) else { return }

        withAnimation(.easeInOut(duration: 0.4)) {
            mapPosition = .region(MKCoordinateRegion(
                center: annotation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
            ))
        }
    }

    // MARK: - Day Filter

    /// Updates the day filter and re-fits the map to visible annotations.
    func selectDayFilter(_ index: Int?) {
        selectedDayFilter = index
        selectedAnnotationId = nil
        // Delay fit so annotations recompute first
        Task { @MainActor in
            fitMapToAnnotations()
        }
    }

    // MARK: - Day Labels

    /// Returns a short label like "Day 1".
    func shortDayLabel(for index: Int) -> String {
        "Day \(index + 1)"
    }

    /// Returns a full label like "Day 1 · Wed Jan 15".
    func dayLabel(for index: Int) -> String {
        guard let date = Trip.utcCalendar.date(byAdding: .day, value: index, to: trip.startDate) else {
            return "Day \(index + 1)"
        }
        let formatter = Trip.utcDateFormatter(format: "EEE MMM d")
        return "Day \(index + 1) · \(formatter.string(from: date))"
    }
}
