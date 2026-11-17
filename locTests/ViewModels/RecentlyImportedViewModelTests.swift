//
//  RecentlyImportedViewModelTests.swift
//  locTests
//
//  Tests for RecentlyImportedViewModel's pure geometry helpers (radius filter and bounding box).
//

import XCTest
import CoreLocation
@testable import loc

final class RecentlyImportedViewModelTests: XCTestCase {

    // MARK: - Helpers

    /// Union Square, Manhattan.
    private let origin = CLLocation(latitude: 40.7359, longitude: -73.9911)

    /// Builds a lightweight place at the given coordinates.
    private func place(_ id: String, lat: Double?, lon: Double?) -> LightweightPlace {
        LightweightPlace(place_id: id, name: id, latitude: lat, longitude: lon, latest_review_photo: nil)
    }

    // MARK: - Radius Filter

    func testPlacesWithinRadius_KeepsNearbyDropsFarAndPreservesOrder() {
        let places = [
            place("brooklyn", lat: 40.6782, lon: -73.9442),    // ~7 km
            place("philly", lat: 39.9526, lon: -75.1652),      // ~130 km
            place("williamsburg", lat: 40.7081, lon: -73.9571) // ~4 km
        ]
        let result = RecentlyImportedViewModel.places(
            places, within: RecentlyImportedViewModel.nearbyRadiusMeters, of: origin
        )
        XCTAssertEqual(result.map(\.place_id), ["brooklyn", "williamsburg"])
    }

    func testPlacesWithinRadius_DropsPlacesWithoutCoordinates() {
        let places = [place("nocoords", lat: nil, lon: nil), place("halfcoords", lat: 40.7, lon: nil)]
        let result = RecentlyImportedViewModel.places(places, within: 32_187, of: origin)
        XCTAssertTrue(result.isEmpty)
    }

    func testPlacesWithinRadius_DropsDuplicatePlaceIds() {
        let places = [place("a", lat: 40.73, lon: -73.99), place("a", lat: 40.73, lon: -73.99)]
        let result = RecentlyImportedViewModel.places(places, within: 32_187, of: origin)
        XCTAssertEqual(result.count, 1)
    }

    func testPlacesWithinRadius_ExcludesJustOutsideTwentyMiles() {
        // ~0.3 degrees of latitude is ~33.4 km, just past the 32.2 km radius.
        let places = [place("edge", lat: origin.coordinate.latitude + 0.3, lon: origin.coordinate.longitude)]
        let result = RecentlyImportedViewModel.places(
            places, within: RecentlyImportedViewModel.nearbyRadiusMeters, of: origin
        )
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Bounding Box

    func testBoundingBox_ContainsRadiusCircle() {
        let box = RecentlyImportedViewModel.boundingBox(around: origin.coordinate, radiusMeters: 32_187)
        let north = CLLocation(latitude: box.maxLat, longitude: origin.coordinate.longitude)
        let east = CLLocation(latitude: origin.coordinate.latitude, longitude: box.maxLon)
        XCTAssertGreaterThanOrEqual(origin.distance(from: north), 32_000)
        XCTAssertGreaterThanOrEqual(origin.distance(from: east), 32_000)
        XCTAssertLessThan(box.minLon, box.maxLon)
        XCTAssertLessThan(box.minLat, box.maxLat)
    }

    func testBoundingBox_ClampsLatitudeNearPoles() {
        let box = RecentlyImportedViewModel.boundingBox(
            around: CLLocationCoordinate2D(latitude: 89.9, longitude: 0), radiusMeters: 32_187
        )
        XCTAssertLessThanOrEqual(box.maxLat, 90)
    }
}
