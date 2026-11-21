//
//  PlaceCityGeocoder.swift
//  loc
//
//  Last-resort city lookup for a place with no usable city or address: reverse geocodes its coordinate.
//

import Foundation
import CoreLocation

enum PlaceCityGeocoder {
    /// Returns the locality (e.g. "Tokyo") of a coordinate, or nil if geocoding fails or finds none.
    static func locality(of coordinate: CLLocationCoordinate2D) async -> String? {
        guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        // A fresh geocoder per call: CLGeocoder cancels overlapping requests on one instance.
        let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location)
        let name = placemarks?.first?.locality?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (name?.isEmpty == false) ? name : nil
    }
}
