//
//  NearbyDiscoverySheetViewModel.swift
//  loc
//
//  Manages the state for the nearby discovery sheet, holding MKMapItem
//  search results and creating placeholder DetailPlace objects for
//  immediate navigation. Background enrichment is handled by the
//  existing selectPlaceAndFetchDetails pipeline.
//

import Foundation
import MapKit
import CoreLocation

@MainActor
class NearbyDiscoverySheetViewModel: ObservableObject {

    // MARK: - Singleton

    static let shared = NearbyDiscoverySheetViewModel()

    private init() {}

    // MARK: - Published State

    @Published private(set) var mapItems: [MKMapItem] = []
    @Published private(set) var isLoading: Bool = false

    /// The coordinate where the user tapped, used for distance calculations in cards.
    private(set) var searchCoordinate: CLLocationCoordinate2D?

    // MARK: - Callback

    /// Fired when a place is resolved and ready for navigation.
    var onPlaceResolved: ((DetailPlace) -> Void)?

    // MARK: - Public Methods

    /// Sets the sheet into a loading state before results arrive.
    func setLoading() {
        mapItems = []
        searchCoordinate = nil
        isLoading = true
    }

    /// Populates the sheet with MKLocalSearch results and clears loading state.
    func setResults(_ items: [MKMapItem], searchCoordinate: CLLocationCoordinate2D) {
        self.mapItems = items
        self.searchCoordinate = searchCoordinate
        self.isLoading = false
    }

    /// Creates a placeholder DetailPlace from the selected MKMapItem for immediate navigation.
    func selectMapItem(_ mapItem: MKMapItem) {
        let placeholder = createPlaceholderFromMapItem(mapItem)
        onPlaceResolved?(placeholder)
    }

    /// Clears all state when the sheet is dismissed.
    func clear() {
        mapItems = []
        searchCoordinate = nil
        isLoading = false
    }

    /// Creates a minimal DetailPlace from an MKMapItem for immediate display.
    /// Used by both sheet selection and auto-navigate (single result) flows.
    func createPlaceholderFromMapItem(_ mapItem: MKMapItem) -> DetailPlace {
        let coordinate = mapItem.placemark.coordinate
        let address = formatAddress(from: mapItem.placemark)

        return DetailPlace(
            googlePlaceId: "",
            name: mapItem.name ?? "Unknown Place",
            address: address,
            coordinate: CLLocationCoordinate2D(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            ),
            source: "apple"
        )
    }

    /// Formats an address string from a placemark's components.
    private func formatAddress(from placemark: MKPlacemark) -> String {
        let components = [
            placemark.subThoroughfare,
            placemark.thoroughfare,
            placemark.locality,
            placemark.administrativeArea
        ].compactMap { $0 }

        if components.isEmpty {
            return placemark.title ?? ""
        }

        return components.joined(separator: " ")
    }
}
