//
//  LightweightPlaceListTests.swift
//  locTests
//
//  Tests for LightweightPlaceList Codable decoding, WKT geometry parsing,
//  GeoJSON fallback, and computed collaboration properties.
//

import XCTest
import CoreLocation
@testable import loc

final class LightweightPlaceListTests: XCTestCase {

    // MARK: - Helpers

    /// Decodes a LightweightPlaceList from a JSON dictionary.
    private func decodeListJSON(_ dict: [String: Any]) throws -> LightweightPlaceList {
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(LightweightPlaceList.self, from: data)
    }

    /// Returns a minimal valid JSON dictionary for a LightweightPlaceList.
    private func minimalListJSON(name: String = "My List") -> [String: Any] {
        return [
            "list_id": UUID().uuidString,
            "name": name,
            "is_public": true,
            "place_count": 5
        ]
    }

    // MARK: - Basic Decoding

    func testDecodeMinimalList() throws {
        let json = minimalListJSON(name: "Coffee Spots")
        let list = try decodeListJSON(json)

        XCTAssertEqual(list.name, "Coffee Spots")
        XCTAssertTrue(list.is_public)
        XCTAssertEqual(list.place_count, 5)
        XCTAssertNil(list.averageLocation)
    }

    func testDecodeAllOptionalFields() throws {
        var json = minimalListJSON()
        json["image"] = "https://example.com/image.jpg"
        json["created_at"] = "2025-01-01T00:00:00Z"
        json["updated_at"] = "2025-06-01T00:00:00Z"
        json["distance_meters"] = 1500.5
        json["city"] = "New York"
        json["description"] = "Best coffee in NYC"
        json["collaborator_count"] = 3
        json["is_shared"] = true
        json["owner_name"] = "Alice"
        json["user_role"] = "editor"

        let list = try decodeListJSON(json)

        XCTAssertEqual(list.image, "https://example.com/image.jpg")
        XCTAssertEqual(list.distance_meters, 1500.5)
        XCTAssertEqual(list.city, "New York")
        XCTAssertEqual(list.description, "Best coffee in NYC")
        XCTAssertEqual(list.collaborator_count, 3)
        XCTAssertEqual(list.is_shared, true)
        XCTAssertEqual(list.owner_name, "Alice")
        XCTAssertEqual(list.user_role, "editor")
    }

    func testPlaceCountDefaultsToZeroWhenMissing() throws {
        let json: [String: Any] = [
            "list_id": UUID().uuidString,
            "name": "Empty List",
            "is_public": false
        ]
        let list = try decodeListJSON(json)
        XCTAssertEqual(list.place_count, 0)
    }

    // MARK: - WKT Geometry Parsing

    func testParseWKTPoint() throws {
        var json = minimalListJSON()
        json["average_location"] = "POINT(-73.98 40.76)"

        let list = try decodeListJSON(json)
        let coord = list.averageLocation

        XCTAssertNotNil(coord)
        XCTAssertEqual(coord!.latitude, 40.76, accuracy: 0.001)
        XCTAssertEqual(coord!.longitude, -73.98, accuracy: 0.001)
    }

    func testParseWKTPointWithNegativeCoordinates() throws {
        var json = minimalListJSON()
        json["average_location"] = "POINT(-122.4194 -37.7749)"

        let list = try decodeListJSON(json)
        let coord = list.averageLocation

        XCTAssertNotNil(coord)
        XCTAssertEqual(coord!.latitude, -37.7749, accuracy: 0.0001)
        XCTAssertEqual(coord!.longitude, -122.4194, accuracy: 0.0001)
    }

    func testParseWKTPointWithHighPrecision() throws {
        var json = minimalListJSON()
        json["average_location"] = "POINT(-73.985428 40.748817)"

        let list = try decodeListJSON(json)
        let coord = list.averageLocation

        XCTAssertNotNil(coord)
        XCTAssertEqual(coord!.latitude, 40.748817, accuracy: 0.000001)
        XCTAssertEqual(coord!.longitude, -73.985428, accuracy: 0.000001)
    }

    func testNilAverageLocationReturnsNil() throws {
        let list = try decodeListJSON(minimalListJSON())
        XCTAssertNil(list.averageLocation)
    }

    func testInvalidWKTStringReturnsNil() throws {
        var json = minimalListJSON()
        json["average_location"] = "INVALID_STRING"

        let list = try decodeListJSON(json)
        XCTAssertNil(list.averageLocation)
    }

    // MARK: - GeoJSON Fallback

    func testDecodeGeoJSONFallback() throws {
        var json = minimalListJSON()
        json["average_location"] = [
            "type": "Point",
            "coordinates": [-73.98, 40.76]
        ] as [String: Any]

        let list = try decodeListJSON(json)
        let coord = list.averageLocation

        XCTAssertNotNil(coord)
        XCTAssertEqual(coord!.latitude, 40.76, accuracy: 0.001)
        XCTAssertEqual(coord!.longitude, -73.98, accuracy: 0.001)
    }

    // MARK: - Collaboration Computed Properties

    func testHasCollaboratorsWhenCountPositive() {
        let list = LightweightPlaceList(
            list_id: "1", name: "Shared", is_public: true,
            image: nil, created_at: nil, updated_at: nil,
            distance_meters: nil, place_count: 3, city: nil,
            collaborator_count: 2
        )
        XCTAssertTrue(list.hasCollaborators)
    }

    func testHasCollaboratorsWhenCountZero() {
        let list = LightweightPlaceList(
            list_id: "1", name: "Solo", is_public: true,
            image: nil, created_at: nil, updated_at: nil,
            distance_meters: nil, place_count: 3, city: nil,
            collaborator_count: 0
        )
        XCTAssertFalse(list.hasCollaborators)
    }

    func testHasCollaboratorsWhenCountNil() {
        let list = LightweightPlaceList(
            list_id: "1", name: "Unknown", is_public: true,
            image: nil, created_at: nil, updated_at: nil,
            distance_meters: nil, place_count: 3, city: nil
        )
        XCTAssertFalse(list.hasCollaborators)
    }

    func testIsSharedWithMe() {
        let shared = LightweightPlaceList(
            list_id: "1", name: "Shared", is_public: true,
            image: nil, created_at: nil, updated_at: nil,
            distance_meters: nil, place_count: 0, city: nil,
            is_shared: true
        )
        XCTAssertTrue(shared.isSharedWithMe)

        let owned = LightweightPlaceList(
            list_id: "2", name: "Owned", is_public: true,
            image: nil, created_at: nil, updated_at: nil,
            distance_meters: nil, place_count: 0, city: nil,
            is_shared: false
        )
        XCTAssertFalse(owned.isSharedWithMe)
    }

    func testIsCollaborativeWhenSharedOrHasCollaborators() {
        let sharedWithMe = LightweightPlaceList(
            list_id: "1", name: "A", is_public: true,
            image: nil, created_at: nil, updated_at: nil,
            distance_meters: nil, place_count: 0, city: nil,
            is_shared: true
        )
        XCTAssertTrue(sharedWithMe.isCollaborative)

        let ownedWithCollaborators = LightweightPlaceList(
            list_id: "2", name: "B", is_public: true,
            image: nil, created_at: nil, updated_at: nil,
            distance_meters: nil, place_count: 0, city: nil,
            collaborator_count: 1
        )
        XCTAssertTrue(ownedWithCollaborators.isCollaborative)

        let solo = LightweightPlaceList(
            list_id: "3", name: "C", is_public: true,
            image: nil, created_at: nil, updated_at: nil,
            distance_meters: nil, place_count: 0, city: nil
        )
        XCTAssertFalse(solo.isCollaborative)
    }

    // MARK: - Encode/Decode Round Trip

    func testEncodeDecodeRoundTrip() throws {
        let original = LightweightPlaceList(
            list_id: "abc-123",
            name: "Round Trip List",
            is_public: false,
            image: "https://example.com/img.jpg",
            created_at: "2025-01-01",
            updated_at: "2025-06-01",
            distance_meters: 2500.0,
            place_count: 10,
            city: "Chicago",
            description: "A great list",
            average_location_raw: "POINT(-87.6298 41.8781)",
            collaborator_count: 2,
            is_shared: true
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LightweightPlaceList.self, from: data)

        XCTAssertEqual(decoded.list_id, "abc-123")
        XCTAssertEqual(decoded.name, "Round Trip List")
        XCTAssertFalse(decoded.is_public)
        XCTAssertEqual(decoded.place_count, 10)
        XCTAssertEqual(decoded.city, "Chicago")
        XCTAssertEqual(decoded.collaborator_count, 2)
        XCTAssertEqual(decoded.is_shared, true)

        let coord = decoded.averageLocation
        XCTAssertNotNil(coord)
        XCTAssertEqual(coord!.latitude, 41.8781, accuracy: 0.001)
        XCTAssertEqual(coord!.longitude, -87.6298, accuracy: 0.001)
    }
}
