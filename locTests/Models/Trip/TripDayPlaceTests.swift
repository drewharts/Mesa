//
//  TripDayPlaceTests.swift
//  locTests
//
//  Tests for TripDayPlace Codable decoding, asLightweightPlace conversion, and ideasDayIndex.
//

import XCTest
@testable import loc

final class TripDayPlaceTests: XCTestCase {

    // MARK: - Helpers

    /// Decodes a TripDayPlace from a JSON dictionary.
    private func decodePlaceJSON(_ dict: [String: Any]) throws -> TripDayPlace {
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(TripDayPlace.self, from: data)
    }

    /// Returns a minimal valid JSON dictionary for a TripDayPlace.
    private func minimalJSON(
        dayPlaceId: String = "dp-1",
        tripId: String = "trip-1",
        placeId: String = "place-1",
        dayIndex: Int = 0,
        sortOrder: Int = 0
    ) -> [String: Any] {
        [
            "day_place_id": dayPlaceId,
            "trip_id": tripId,
            "place_id": placeId,
            "day_index": dayIndex,
            "sort_order": sortOrder
        ]
    }

    /// Returns a fully populated JSON dictionary.
    private func fullJSON() -> [String: Any] {
        [
            "day_place_id": "dp-full",
            "trip_id": "trip-full",
            "place_id": "place-full",
            "day_index": 2,
            "sort_order": 1,
            "added_by": "user-1",
            "note": "Great spot for lunch",
            "place_name": "The Cafe",
            "place_address": "456 Oak Ave",
            "place_latitude": 37.7749,
            "place_longitude": -122.4194,
            "place_photo": "https://example.com/photo.jpg",
            "added_by_name": "Alice",
            "added_by_photo_url": "https://example.com/alice.jpg",
            "tiktok_url": "https://tiktok.com/video/123",
            "place_type": "restaurant"
        ]
    }

    // MARK: - ideasDayIndex

    func testIdeasDayIndex_IsNegativeOne() {
        XCTAssertEqual(TripDayPlace.ideasDayIndex, -1)
    }

    // MARK: - Codable Decoding

    func testDecodeMinimal() throws {
        let place = try decodePlaceJSON(minimalJSON())

        XCTAssertEqual(place.id, "dp-1")
        XCTAssertEqual(place.tripId, "trip-1")
        XCTAssertEqual(place.placeId, "place-1")
        XCTAssertEqual(place.dayIndex, 0)
        XCTAssertEqual(place.sortOrder, 0)
        XCTAssertNil(place.addedBy)
        XCTAssertNil(place.note)
        XCTAssertNil(place.placeName)
        XCTAssertNil(place.placeAddress)
        XCTAssertNil(place.placeLatitude)
        XCTAssertNil(place.placeLongitude)
        XCTAssertNil(place.placePhoto)
        XCTAssertNil(place.addedByName)
        XCTAssertNil(place.addedByPhotoUrl)
        XCTAssertNil(place.contentUrl)
        XCTAssertNil(place.placeType)
    }

    func testDecodeAllFields() throws {
        let place = try decodePlaceJSON(fullJSON())

        XCTAssertEqual(place.id, "dp-full")
        XCTAssertEqual(place.tripId, "trip-full")
        XCTAssertEqual(place.placeId, "place-full")
        XCTAssertEqual(place.dayIndex, 2)
        XCTAssertEqual(place.sortOrder, 1)
        XCTAssertEqual(place.addedBy, "user-1")
        XCTAssertEqual(place.note, "Great spot for lunch")
        XCTAssertEqual(place.placeName, "The Cafe")
        XCTAssertEqual(place.placeAddress, "456 Oak Ave")
        XCTAssertEqual(place.placeLatitude, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(place.placeLongitude, -122.4194, accuracy: 0.0001)
        XCTAssertEqual(place.placePhoto, "https://example.com/photo.jpg")
        XCTAssertEqual(place.addedByName, "Alice")
        XCTAssertEqual(place.addedByPhotoUrl, "https://example.com/alice.jpg")
        XCTAssertEqual(place.contentUrl, "https://tiktok.com/video/123")
        XCTAssertEqual(place.placeType, "restaurant")
    }

    func testDecodeCodingKeys_SnakeCase() throws {
        // Verify snake_case JSON keys map to camelCase properties
        let json: [String: Any] = [
            "day_place_id": "dp-snake",
            "trip_id": "trip-snake",
            "place_id": "place-snake",
            "day_index": 3,
            "sort_order": 5,
            "added_by": "user-2",
            "place_name": "Snake Place",
            "place_latitude": 40.0,
            "place_longitude": -74.0,
            "added_by_name": "Bob",
            "added_by_photo_url": "https://bob.jpg"
        ]

        let place = try decodePlaceJSON(json)
        XCTAssertEqual(place.id, "dp-snake")
        XCTAssertEqual(place.dayIndex, 3)
        XCTAssertEqual(place.sortOrder, 5)
        XCTAssertEqual(place.placeName, "Snake Place")
        XCTAssertEqual(place.addedByName, "Bob")
    }

    // MARK: - asLightweightPlace

    func testAsLightweightPlace_AllFields() throws {
        let place = try decodePlaceJSON(fullJSON())
        let lightweight = place.asLightweightPlace

        XCTAssertEqual(lightweight.place_id, "place-full")
        XCTAssertEqual(lightweight.name, "The Cafe")
        XCTAssertEqual(lightweight.latitude, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(lightweight.longitude, -122.4194, accuracy: 0.0001)
        XCTAssertEqual(lightweight.latest_review_photo, "https://example.com/photo.jpg")
        XCTAssertEqual(lightweight.content_url, "https://tiktok.com/video/123")
    }

    func testAsLightweightPlace_NilPlaceName_DefaultsToUnknown() throws {
        let place = try decodePlaceJSON(minimalJSON())
        let lightweight = place.asLightweightPlace

        XCTAssertEqual(lightweight.name, "Unknown Place")
    }

    func testAsLightweightPlace_NilPhotoAndContentUrl() throws {
        let place = try decodePlaceJSON(minimalJSON())
        let lightweight = place.asLightweightPlace

        XCTAssertNil(lightweight.latest_review_photo)
        XCTAssertNil(lightweight.content_url)
    }

    func testAsLightweightPlace_NilCoordinates() throws {
        let place = try decodePlaceJSON(minimalJSON())
        let lightweight = place.asLightweightPlace

        XCTAssertNil(lightweight.latitude)
        XCTAssertNil(lightweight.longitude)
    }

    // MARK: - Codable Round Trip

    func testEncodeDecodeRoundTrip() throws {
        let original = try decodePlaceJSON(fullJSON())
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TripDayPlace.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.tripId, original.tripId)
        XCTAssertEqual(decoded.placeId, original.placeId)
        XCTAssertEqual(decoded.dayIndex, original.dayIndex)
        XCTAssertEqual(decoded.sortOrder, original.sortOrder)
        XCTAssertEqual(decoded.placeName, original.placeName)
        XCTAssertEqual(decoded.placeLatitude, original.placeLatitude)
        XCTAssertEqual(decoded.contentUrl, original.contentUrl)
    }

    // MARK: - Equatable

    func testEquatable() throws {
        let json = fullJSON()
        let a = try decodePlaceJSON(json)
        let b = try decodePlaceJSON(json)
        XCTAssertEqual(a, b)
    }

    func testNotEqual_DifferentId() throws {
        let a = try decodePlaceJSON(minimalJSON(dayPlaceId: "dp-a"))
        let b = try decodePlaceJSON(minimalJSON(dayPlaceId: "dp-b"))
        XCTAssertNotEqual(a, b)
    }
}
