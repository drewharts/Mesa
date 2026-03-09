//
//  PlaceAnnotationTests.swift
//  locTests
//
//  Tests for PlaceAnnotation PostGIS GeoJSON coordinate decoding.
//

import XCTest
import CoreLocation
@testable import loc

final class PlaceAnnotationTests: XCTestCase {

    // MARK: - Helpers

    /// Decodes a PlaceAnnotation from a JSON dictionary.
    private func decodeAnnotationJSON(_ dict: [String: Any]) throws -> PlaceAnnotation {
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(PlaceAnnotation.self, from: data)
    }

    /// Returns a valid GeoJSON Point dictionary.
    private func geoJSONPoint(lon: Double, lat: Double) -> [String: Any] {
        return ["type": "Point", "coordinates": [lon, lat]]
    }

    // MARK: - GeoJSON Coordinate Decoding

    func testDecodeGeoJSONCoordinate() throws {
        let json: [String: Any] = [
            "id": "place-1",
            "name": "Test Place",
            "coordinate": geoJSONPoint(lon: -122.4194, lat: 37.7749),
            "user_ids": ["user-a", "user-b"],
            "place_type": "restaurant"
        ]

        let annotation = try decodeAnnotationJSON(json)

        XCTAssertEqual(annotation.id, "place-1")
        XCTAssertEqual(annotation.name, "Test Place")
        XCTAssertEqual(annotation.coordinate.latitude, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(annotation.coordinate.longitude, -122.4194, accuracy: 0.0001)
        XCTAssertEqual(annotation.userIds, ["user-a", "user-b"])
        XCTAssertEqual(annotation.placeType, "restaurant")
    }

    func testDecodeNegativeCoordinates() throws {
        let json: [String: Any] = [
            "id": "place-2",
            "name": "Southern Place",
            "coordinate": geoJSONPoint(lon: -43.1729, lat: -22.9068),
            "user_ids": ["user-c"],
            "place_type": "cafe"
        ]

        let annotation = try decodeAnnotationJSON(json)

        XCTAssertEqual(annotation.coordinate.latitude, -22.9068, accuracy: 0.0001)
        XCTAssertEqual(annotation.coordinate.longitude, -43.1729, accuracy: 0.0001)
    }

    func testDecodeMissingCoordinatesFallsBackToZero() throws {
        let json: [String: Any] = [
            "id": "place-3",
            "name": "No Coords",
            "coordinate": ["type": "Point", "coordinates": [] as [Double]],
            "user_ids": [],
            "place_type": "unknown"
        ]

        let annotation = try decodeAnnotationJSON(json)

        // Should fallback to 0,0 when coordinates array is empty
        XCTAssertEqual(annotation.coordinate.latitude, 0, accuracy: 0.0001)
        XCTAssertEqual(annotation.coordinate.longitude, 0, accuracy: 0.0001)
    }

    func testDecodeNullCoordinatesFallsBackToZero() throws {
        // coordinates key present but null
        let jsonString = """
        {
            "id": "place-4",
            "name": "Null Coords",
            "coordinate": {"type": "Point", "coordinates": null},
            "user_ids": [],
            "place_type": "park"
        }
        """
        let data = jsonString.data(using: .utf8)!
        let annotation = try JSONDecoder().decode(PlaceAnnotation.self, from: data)

        XCTAssertEqual(annotation.coordinate.latitude, 0, accuracy: 0.0001)
        XCTAssertEqual(annotation.coordinate.longitude, 0, accuracy: 0.0001)
    }

    // MARK: - Memberwise Initializer

    func testMemberwiseInitializer() {
        let coord = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
        let annotation = PlaceAnnotation(
            id: "london-1",
            name: "London Place",
            coordinate: coord,
            userIds: ["user-x"],
            placeType: "pub"
        )

        XCTAssertEqual(annotation.id, "london-1")
        XCTAssertEqual(annotation.name, "London Place")
        XCTAssertEqual(annotation.coordinate.latitude, 51.5074, accuracy: 0.0001)
        XCTAssertEqual(annotation.placeType, "pub")
    }

    // MARK: - User IDs

    func testEmptyUserIds() throws {
        let json: [String: Any] = [
            "id": "place-5",
            "name": "Empty Users",
            "coordinate": geoJSONPoint(lon: 0, lat: 0),
            "user_ids": [] as [String],
            "place_type": "store"
        ]

        let annotation = try decodeAnnotationJSON(json)
        XCTAssertTrue(annotation.userIds.isEmpty)
    }

    func testMultipleUserIds() throws {
        let json: [String: Any] = [
            "id": "place-6",
            "name": "Popular Place",
            "coordinate": geoJSONPoint(lon: -73.98, lat: 40.76),
            "user_ids": ["a", "b", "c", "d"],
            "place_type": "restaurant"
        ]

        let annotation = try decodeAnnotationJSON(json)
        XCTAssertEqual(annotation.userIds.count, 4)
    }
}
