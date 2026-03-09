//
//  DetailPlaceTests.swift
//  locTests
//
//  Tests for DetailPlace custom Codable decoding, encoding, and computed properties.
//

import XCTest
import CoreLocation
@testable import loc

final class DetailPlaceTests: XCTestCase {

    // MARK: - Helpers

    /// Decodes a DetailPlace from a JSON dictionary.
    private func decodePlaceJSON(_ dict: [String: Any]) throws -> DetailPlace {
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(DetailPlace.self, from: data)
    }

    /// Returns a minimal valid JSON dictionary for a DetailPlace.
    private func minimalPlaceJSON(id: String = UUID().uuidString, name: String = "Test Place") -> [String: Any] {
        return ["id": id, "name": name]
    }

    // MARK: - Basic Decoding

    func testDecodeMinimalPlace() throws {
        let id = UUID().uuidString
        let place = try decodePlaceJSON(minimalPlaceJSON(id: id, name: "Cafe Roma"))

        XCTAssertEqual(place.id.uuidString.uppercased(), id.uppercased())
        XCTAssertEqual(place.name, "Cafe Roma")
        XCTAssertNil(place.address)
        XCTAssertNil(place.coordinate)
    }

    func testDecodeAllOptionalFields() throws {
        var json = minimalPlaceJSON(name: "Full Place")
        json["address"] = "123 Main St"
        json["city"] = "San Francisco"
        json["phone"] = "+14155551234"
        json["rating"] = 4.5
        json["priceLevel"] = "$$"
        json["reservable"] = true
        json["servesBreakfast"] = true
        json["menu_url"] = "https://example.com/menu"
        json["website"] = "https://example.com"
        json["is_custom"] = false

        let place = try decodePlaceJSON(json)

        XCTAssertEqual(place.address, "123 Main St")
        XCTAssertEqual(place.city, "San Francisco")
        XCTAssertEqual(place.phone, "+14155551234")
        XCTAssertEqual(place.rating, 4.5)
        XCTAssertEqual(place.priceLevel, "$$")
        XCTAssertEqual(place.reservable, true)
        XCTAssertEqual(place.servesBreakfast, true)
        XCTAssertEqual(place.menuUrl, "https://example.com/menu")
        XCTAssertEqual(place.websiteUrl, "https://example.com")
        XCTAssertEqual(place.isCustom, false)
    }

    // MARK: - Coordinate Decoding Variants

    func testDecodeCoordinatesBackendFormat() throws {
        var json = minimalPlaceJSON()
        json["coordinates"] = ["latitude": 37.7749, "longitude": -122.4194]

        let place = try decodePlaceJSON(json)

        XCTAssertNotNil(place.coordinate)
        XCTAssertEqual(place.coordinate!.latitude, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(place.coordinate!.longitude, -122.4194, accuracy: 0.0001)
    }

    func testDecodeCoordinateSingularFormat() throws {
        var json = minimalPlaceJSON()
        json["coordinate"] = ["latitude": 40.7128, "longitude": -74.0060]

        let place = try decodePlaceJSON(json)

        XCTAssertNotNil(place.coordinate)
        XCTAssertEqual(place.coordinate!.latitude, 40.7128, accuracy: 0.0001)
        XCTAssertEqual(place.coordinate!.longitude, -74.0060, accuracy: 0.0001)
    }

    func testDecodeNoCoordinatesReturnsNil() throws {
        let place = try decodePlaceJSON(minimalPlaceJSON())
        XCTAssertNil(place.coordinate)
    }

    // MARK: - Rating Count Variants

    func testDecodeUserRatingsTotalField() throws {
        var json = minimalPlaceJSON()
        json["user_ratings_total"] = 250

        let place = try decodePlaceJSON(json)
        XCTAssertEqual(place.userRatingsTotal, 250)
    }

    func testDecodeRatingCountLegacyField() throws {
        var json = minimalPlaceJSON()
        json["ratingCount"] = 100

        let place = try decodePlaceJSON(json)
        XCTAssertEqual(place.userRatingsTotal, 100)
    }

    func testUserRatingsTotalTakesPrecedenceOverRatingCount() throws {
        var json = minimalPlaceJSON()
        json["user_ratings_total"] = 300
        json["ratingCount"] = 100

        let place = try decodePlaceJSON(json)
        XCTAssertEqual(place.userRatingsTotal, 300)
    }

    // MARK: - Google Place ID Variants

    func testDecodeGooglePlaceIdBackendField() throws {
        var json = minimalPlaceJSON()
        json["google_place_id"] = "ChIJ_abc123"

        let place = try decodePlaceJSON(json)
        XCTAssertEqual(place.googlePlaceId, "ChIJ_abc123")
    }

    func testDecodeGooglePlacesIdLegacyField() throws {
        var json = minimalPlaceJSON()
        json["googlePlacesId"] = "ChIJ_legacy456"

        let place = try decodePlaceJSON(json)
        XCTAssertEqual(place.googlePlaceId, "ChIJ_legacy456")
    }

    func testGooglePlaceIdBackendTakesPrecedence() throws {
        var json = minimalPlaceJSON()
        json["google_place_id"] = "ChIJ_backend"
        json["googlePlacesId"] = "ChIJ_legacy"

        let place = try decodePlaceJSON(json)
        XCTAssertEqual(place.googlePlaceId, "ChIJ_backend")
    }

    // MARK: - Source Inference

    func testSourceInferredFromGooglePlaceId() throws {
        var json = minimalPlaceJSON()
        json["google_place_id"] = "ChIJ_abc"

        let place = try decodePlaceJSON(json)
        XCTAssertEqual(place.source, "google")
    }

    func testSourceInferredFromMapboxId() throws {
        var json = minimalPlaceJSON()
        json["mapboxId"] = "poi.12345"

        let place = try decodePlaceJSON(json)
        XCTAssertEqual(place.source, "mapbox")
    }

    func testExplicitSourceNotOverridden() throws {
        var json = minimalPlaceJSON()
        json["source"] = "manual"
        json["google_place_id"] = "ChIJ_abc"

        let place = try decodePlaceJSON(json)
        XCTAssertEqual(place.source, "manual")
    }

    // MARK: - Open Hours Polymorphism

    func testDecodeOpenHoursAsStringArray() throws {
        var json = minimalPlaceJSON()
        json["openHours"] = ["Monday: 9 AM–5 PM", "Tuesday: 9 AM–5 PM"]

        let place = try decodePlaceJSON(json)
        XCTAssertEqual(place.openHours, ["Monday: 9 AM–5 PM", "Tuesday: 9 AM–5 PM"])
    }

    func testDecodeOpenHoursAsObjectArray() throws {
        var json = minimalPlaceJSON()
        json["openHours"] = [
            ["day": "Monday", "hours": "11 AM–11 PM"],
            ["day": "Tuesday", "hours": "11 AM–10 PM"]
        ]

        let place = try decodePlaceJSON(json)
        XCTAssertEqual(place.openHours?.count, 2)
        XCTAssertEqual(place.openHours?[0], "Monday: 11 AM–11 PM")
        XCTAssertEqual(place.openHours?[1], "Tuesday: 11 AM–10 PM")
    }

    // MARK: - Photo URL Fallback

    func testDecodePhotoUrlsArray() throws {
        var json = minimalPlaceJSON()
        json["photoUrls"] = ["https://example.com/1.jpg", "https://example.com/2.jpg"]

        let place = try decodePlaceJSON(json)
        XCTAssertEqual(place.photoUrls?.count, 2)
    }

    func testDecodeThumbnailUrlFallback() throws {
        var json = minimalPlaceJSON()
        json["thumbnailUrl"] = "https://example.com/thumb.jpg"

        let place = try decodePlaceJSON(json)
        XCTAssertEqual(place.photoUrls, ["https://example.com/thumb.jpg"])
    }

    // MARK: - Placeholder ID

    func testPlaceholderUUID() {
        let place = DetailPlace(
            googlePlaceId: "ChIJ_test",
            name: "Test",
            address: nil,
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            source: "google"
        )
        XCTAssertTrue(place.hasPlaceholderID)
    }

    func testRegularUUIDIsNotPlaceholder() {
        let place = DetailPlace()
        XCTAssertFalse(place.hasPlaceholderID)
    }

    // MARK: - Encode/Decode Round Trip

    func testEncodeDecodeRoundTrip() throws {
        var original = DetailPlace()
        original.name = "Round Trip Cafe"
        original.address = "456 Oak Ave"
        original.city = "Portland"
        original.rating = 4.2
        original.coordinate = CLLocationCoordinate2D(latitude: 45.5, longitude: -122.6)
        original.googlePlaceId = "ChIJ_round_trip"
        original.source = "google"

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DetailPlace.self, from: encoded)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, "Round Trip Cafe")
        XCTAssertEqual(decoded.address, "456 Oak Ave")
        XCTAssertEqual(decoded.city, "Portland")
        XCTAssertEqual(decoded.rating, 4.2)
        XCTAssertNotNil(decoded.coordinate)
        XCTAssertEqual(decoded.coordinate!.latitude, 45.5, accuracy: 0.0001)
        XCTAssertEqual(decoded.googlePlaceId, "ChIJ_round_trip")
        XCTAssertEqual(decoded.source, "google")
    }

    // MARK: - Invalid ID Handling

    func testInvalidUUIDStringGeneratesNewUUID() throws {
        let json: [String: Any] = ["id": "not-a-uuid", "name": "Bad ID Place"]
        let place = try decodePlaceJSON(json)

        // Should not crash — falls back to a new UUID
        XCTAssertFalse(place.name.isEmpty)
    }

    // MARK: - Coordinate Validation Extension

    func testValidCoordinateIsValidForNavigation() {
        let coord = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        XCTAssertTrue(coord.isValidForNavigation)
    }

    func testZeroCoordinateIsNotValidForNavigation() {
        let coord = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        XCTAssertFalse(coord.isValidForNavigation)
    }

    // MARK: - LightweightPlace Conversion

    func testAsLightweightPlace() {
        var place = DetailPlace()
        place.name = "Conversion Test"
        place.photoUrls = ["https://example.com/photo.jpg"]

        let lightweight = place.asLightweightPlace
        XCTAssertEqual(lightweight.name, "Conversion Test")
        XCTAssertEqual(lightweight.place_id, place.id.uuidString)
        XCTAssertEqual(lightweight.latest_review_photo, "https://example.com/photo.jpg")
    }
}
