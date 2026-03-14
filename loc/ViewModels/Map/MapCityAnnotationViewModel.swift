//
//  MapCityAnnotationViewModel.swift
//  loc
//
//  Child ViewModel for city-level map annotations.
//  Fetches and manages aggregated city annotations when the user zooms out.
//

import Foundation
import MapKit

@MainActor
class MapCityAnnotationViewModel: ObservableObject {
    @Published var cityAnnotations: [CityAnnotation] = []
    @Published var isLoading: Bool = false

    private let placeService: PlaceService
    private var currentLoadTask: Task<Void, Never>?
    private var lastLoadedRegion: MKCoordinateRegion?

    // MARK: - Zoom Threshold Constants

    /// Zoom out threshold: show city annotations when latitudeDelta exceeds this.
    static let zoomOutThreshold: Double = 0.55

    /// Zoom in threshold: show place annotations when latitudeDelta drops below this.
    static let zoomInThreshold: Double = 0.45

    init(placeService: PlaceService) {
        self.placeService = placeService
    }

    // MARK: - Public Methods

    /// Fetches city annotations for the given viewport bounds and user.
    func fetchCityAnnotations(region: MKCoordinateRegion, userId: String) async {
        if let lastRegion = lastLoadedRegion, !shouldReloadForRegion(region, lastRegion: lastRegion) {
            return
        }

        currentLoadTask?.cancel()

        let task = Task { @MainActor in
            guard !Task.isCancelled else { return }

            isLoading = true

            let bounds = ViewportBounds(
                northLat: region.center.latitude + (region.span.latitudeDelta / 2),
                southLat: region.center.latitude - (region.span.latitudeDelta / 2),
                eastLng: region.center.longitude + (region.span.longitudeDelta / 2),
                westLng: region.center.longitude - (region.span.longitudeDelta / 2)
            )

            do {
                guard !Task.isCancelled else {
                    isLoading = false
                    return
                }

                let annotations = try await placeService.fetchCityAnnotationsInViewport(
                    northLat: bounds.northLat,
                    southLat: bounds.southLat,
                    eastLng: bounds.eastLng,
                    westLng: bounds.westLng,
                    userId: userId
                )

                guard !Task.isCancelled else {
                    isLoading = false
                    return
                }

                self.cityAnnotations = Self.filterOverlapping(annotations, latitudeDelta: region.span.latitudeDelta)
                self.lastLoadedRegion = region
            } catch {
                let isCancelled = Task.isCancelled || error is CancellationError || (error as NSError).code == NSURLErrorCancelled
                if !isCancelled {
                    print("❌ [MapCityAnnotationVM] Error fetching city annotations: \(error.localizedDescription)")
                }
            }

            isLoading = false
        }

        currentLoadTask = task
        await task.value
    }

    /// Clears city annotations when zooming back in.
    func clearAnnotations() {
        cityAnnotations = []
        lastLoadedRegion = nil
    }

    // MARK: - Zoom Level Detection

    /// Determines whether the map should show city annotations based on the current zoom level.
    static func shouldShowCityAnnotations(latitudeDelta: Double, isCurrentlyShowingCities: Bool) -> Bool {
        if isCurrentlyShowingCities {
            return latitudeDelta > zoomInThreshold
        } else {
            return latitudeDelta > zoomOutThreshold
        }
    }

    // MARK: - Private Methods

    /// Filters out overlapping city annotations by keeping the highest-count city when two are too close.
    static func filterOverlapping(_ annotations: [CityAnnotation], latitudeDelta: Double) -> [CityAnnotation] {
        let minDistance = latitudeDelta * 0.18
        let sorted = annotations.sorted { $0.placeCount > $1.placeCount }
        var result: [CityAnnotation] = []

        for city in sorted {
            let tooClose = result.contains { existing in
                abs(existing.latitude - city.latitude) < minDistance &&
                abs(existing.longitude - city.longitude) < minDistance
            }
            if !tooClose {
                result.append(city)
            }
        }

        return result
    }

    /// Checks if region change is significant enough to reload city annotations.
    private func shouldReloadForRegion(_ newRegion: MKCoordinateRegion, lastRegion: MKCoordinateRegion) -> Bool {
        let latDiff = abs(newRegion.center.latitude - lastRegion.center.latitude)
        let lngDiff = abs(newRegion.center.longitude - lastRegion.center.longitude)

        let latMovementThreshold = lastRegion.span.latitudeDelta * 0.3
        let lngMovementThreshold = lastRegion.span.longitudeDelta * 0.3
        let centerMoved = latDiff > latMovementThreshold || lngDiff > lngMovementThreshold

        let latSpanChange = abs(newRegion.span.latitudeDelta - lastRegion.span.latitudeDelta)
        let zoomChanged = latSpanChange > (lastRegion.span.latitudeDelta * 0.5)

        return centerMoved || zoomChanged
    }
}
