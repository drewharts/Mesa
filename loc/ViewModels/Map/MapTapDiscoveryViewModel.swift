//
//  MapTapDiscoveryViewModel.swift
//  loc
//
//  Handles tap-to-discover: converts a map coordinate into nearby POIs
//  using MKLocalSearch (Apple CDN), then returns results for the user
//  to choose from. Single results auto-navigate directly.
//

import Foundation
import CoreLocation
import MapKit

/// State for the tap-to-discover flow.
enum TapDiscoveryState: Equatable {
    case idle
    case searching
    case noResults

    static func == (lhs: TapDiscoveryState, rhs: TapDiscoveryState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.searching, .searching), (.noResults, .noResults):
            return true
        default:
            return false
        }
    }
}

@MainActor
class MapTapDiscoveryViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var discoveryState: TapDiscoveryState = .idle

    // MARK: - Callbacks

    /// Fired when a discovery search begins (after debounce passes).
    var onDiscoveryStarted: (() -> Void)?

    /// Fired when multiple nearby places are found and ready for display.
    var onNearbyPlacesFound: (([MKMapItem], CLLocationCoordinate2D) -> Void)?

    /// Fired when exactly one place is found, enabling auto-navigation.
    var onSinglePlaceFound: ((MKMapItem) -> Void)?

    /// Fired when discovery finds no results or encounters an error.
    var onDiscoveryFailed: (() -> Void)?

    // MARK: - Private

    private var currentTask: Task<Void, Never>?
    private var lastTapTime: Date = .distantPast
    private let debounceInterval: TimeInterval = 0.5

    // MARK: - Public Methods

    /// Discovers nearby places at the given coordinate via MKLocalSearch.
    /// Debounces rapid taps (500ms) and cancels any in-flight discovery.
    /// Includes a brief delay before presenting UI to allow annotation taps to cancel.
    func discoverPlace(at coordinate: CLLocationCoordinate2D) {
        let now = Date()
        guard now.timeIntervalSince(lastTapTime) >= debounceInterval else { return }
        lastTapTime = now

        currentTask?.cancel()

        currentTask = Task { [weak self] in
            guard let self else { return }

            // Brief delay so annotation onTapGesture can call resetState() first,
            // preventing discovery UI from flashing when the user tapped an annotation.
            try? await Task.sleep(nanoseconds: 50_000_000)
            guard !Task.isCancelled else { return }

            await self.performDiscovery(at: coordinate)
        }
    }

    /// Executes the MKLocalSearch and delivers results via callbacks.
    private func performDiscovery(at coordinate: CLLocationCoordinate2D) async {
        discoveryState = .searching
        onDiscoveryStarted?()

        do {
            let mapItems = try await searchNearbyPlaces(at: coordinate)

            guard !Task.isCancelled else { return }

            if mapItems.isEmpty {
                showNoResults()
                return
            }

            discoveryState = .idle
            deliverResults(mapItems, coordinate: coordinate)
        } catch {
            if !Task.isCancelled {
                showNoResults()
            }
        }
    }

    /// Delivers search results via the appropriate callback based on result count.
    private func deliverResults(_ mapItems: [MKMapItem], coordinate: CLLocationCoordinate2D) {
        if mapItems.count == 1 {
            onSinglePlaceFound?(mapItems[0])
        } else {
            onNearbyPlacesFound?(mapItems, coordinate)
        }
    }

    /// Resets state to idle and cancels any in-flight task.
    func resetState() {
        currentTask?.cancel()
        discoveryState = .idle
    }

    // MARK: - Private Methods

    /// Searches for all nearby points of interest within 100m using MKLocalPointsOfInterestRequest.
    private func searchNearbyPlaces(at coordinate: CLLocationCoordinate2D) async throws -> [MKMapItem] {
        let request = MKLocalPointsOfInterestRequest(
            center: coordinate,
            radius: 50
        )
        request.pointOfInterestFilter = .includingAll

        let search = MKLocalSearch(request: request)
        let response = try await search.start()

        return sortByDistance(response.mapItems, from: coordinate)
    }

    /// Sorts map items by distance from the tap coordinate.
    private func sortByDistance(_ items: [MKMapItem], from coordinate: CLLocationCoordinate2D) -> [MKMapItem] {
        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return items.sorted { a, b in
            let distA = CLLocation(latitude: a.placemark.coordinate.latitude, longitude: a.placemark.coordinate.longitude)
                .distance(from: origin)
            let distB = CLLocation(latitude: b.placemark.coordinate.latitude, longitude: b.placemark.coordinate.longitude)
                .distance(from: origin)
            return distA < distB
        }
    }

    /// Transitions to noResults state, notifies listeners, and auto-resets after 2 seconds.
    private func showNoResults() {
        onDiscoveryFailed?()
        discoveryState = .noResults
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard let self, self.discoveryState == .noResults else { return }
            self.discoveryState = .idle
        }
    }
}
