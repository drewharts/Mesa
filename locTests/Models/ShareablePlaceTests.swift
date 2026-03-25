//
//  ShareablePlaceTests.swift
//  locTests
//
//  Tests for ShareablePlace deep link URL generation, URL parsing, and round-trip consistency.
//

import XCTest
@testable import loc

final class ShareablePlaceTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a ShareablePlace with all fields populated.
    private func fullPlace(
        id: String = "ABC-123",
        name: String = "Test Cafe",
        address: String? = "123 Main St",
        city: String? = "San Francisco",
        mapboxId: String? = "poi.12345",
        latitude: Double? = 37.7749,
        longitude: Double? = -122.4194
    ) -> ShareablePlace {
        ShareablePlace(
            id: id,
            name: name,
            address: address,
            city: city,
            mapboxId: mapboxId,
            latitude: latitude,
            longitude: longitude
        )
    }

    // MARK: - Deep Link URL Generation

    func testDeepLinkURL_AllFields() {
        let place = fullPlace()
        let url = place.deepLinkURL

        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "loc")
        XCTAssertEqual(url?.host, "place")
        XCTAssertTrue(url?.path.contains("ABC-123") ?? false)

        let components = URLComponents(url: url!, resolvingAgainstBaseURL: false)!
        let query = Dictionary(
            uniqueKeysWithValues: components.queryItems!.map { ($0.name, $0.value) }
        )
        XCTAssertEqual(query["name"], "Test Cafe")
        XCTAssertEqual(query["address"], "123 Main St")
        XCTAssertEqual(query["city"], "San Francisco")
        XCTAssertEqual(query["mapboxId"], "poi.12345")
        XCTAssertEqual(query["lat"], "37.7749")
        XCTAssertEqual(query["lng"], "-122.4194")
    }

    func testDeepLinkURL_NilOptionalFields() {
        let place = ShareablePlace(
            id: "X", name: "Simple", address: nil, city: nil,
            mapboxId: nil, latitude: nil, longitude: nil
        )
        let url = place.deepLinkURL!
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        let names = Set(components.queryItems!.map(\.name))

        XCTAssertTrue(names.contains("name"))
        XCTAssertFalse(names.contains("address"))
        XCTAssertFalse(names.contains("city"))
        XCTAssertFalse(names.contains("mapboxId"))
        XCTAssertFalse(names.contains("lat"))
        XCTAssertFalse(names.contains("lng"))
    }

    func testDeepLinkURL_SpecialCharactersInName() {
        let place = ShareablePlace(
            id: "1", name: "Joe's Bar & Grill", address: nil, city: nil,
            mapboxId: nil, latitude: nil, longitude: nil
        )
        let url = place.deepLinkURL

        XCTAssertNotNil(url)
        // Round-trip: parsing should recover the name
        let parsed = ShareablePlace.from(url: url!)
        XCTAssertEqual(parsed?.name, "Joe's Bar & Grill")
    }

    // MARK: - URL Parsing (from(url:))

    func testFromURL_ValidFullURL() {
        let url = URL(string: "loc://place/ABC-123?name=Test%20Cafe&address=123%20Main&city=SF&mapboxId=poi.1&lat=37.7&lng=-122.4")!
        let place = ShareablePlace.from(url: url)

        XCTAssertNotNil(place)
        XCTAssertEqual(place?.id, "ABC-123")
        XCTAssertEqual(place?.name, "Test Cafe")
        XCTAssertEqual(place?.address, "123 Main")
        XCTAssertEqual(place?.city, "SF")
        XCTAssertEqual(place?.mapboxId, "poi.1")
        XCTAssertEqual(place?.latitude, 37.7, accuracy: 0.001)
        XCTAssertEqual(place?.longitude, -122.4, accuracy: 0.001)
    }

    func testFromURL_MinimalURL() {
        let url = URL(string: "loc://place/ID-1?name=Minimal")!
        let place = ShareablePlace.from(url: url)

        XCTAssertNotNil(place)
        XCTAssertEqual(place?.id, "ID-1")
        XCTAssertEqual(place?.name, "Minimal")
        XCTAssertNil(place?.address)
        XCTAssertNil(place?.city)
        XCTAssertNil(place?.mapboxId)
        XCTAssertNil(place?.latitude)
        XCTAssertNil(place?.longitude)
    }

    func testFromURL_InvalidScheme() {
        let url = URL(string: "https://place/123?name=Bad")!
        XCTAssertNil(ShareablePlace.from(url: url))
    }

    func testFromURL_InvalidHost() {
        let url = URL(string: "loc://list/123?name=Bad")!
        XCTAssertNil(ShareablePlace.from(url: url))
    }

    func testFromURL_MissingName() {
        let url = URL(string: "loc://place/123?address=NoName")!
        XCTAssertNil(ShareablePlace.from(url: url))
    }

    func testFromURL_MissingPathId() {
        let url = URL(string: "loc://place?name=NoId")!
        XCTAssertNil(ShareablePlace.from(url: url))
    }

    func testFromURL_MalformedLatLng() {
        let url = URL(string: "loc://place/1?name=Place&lat=notanumber&lng=also_bad")!
        let place = ShareablePlace.from(url: url)

        XCTAssertNotNil(place)
        XCTAssertNil(place?.latitude)
        XCTAssertNil(place?.longitude)
    }

    func testFromURL_UnknownQueryParams() {
        let url = URL(string: "loc://place/1?name=Place&unknown=value&extra=123")!
        let place = ShareablePlace.from(url: url)

        XCTAssertNotNil(place)
        XCTAssertEqual(place?.name, "Place")
    }

    // MARK: - Round Trip

    func testRoundTrip_AllFields() {
        let original = fullPlace()
        guard let url = original.deepLinkURL else {
            XCTFail("deepLinkURL should not be nil")
            return
        }
        let parsed = ShareablePlace.from(url: url)

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.id, original.id)
        XCTAssertEqual(parsed?.name, original.name)
        XCTAssertEqual(parsed?.address, original.address)
        XCTAssertEqual(parsed?.city, original.city)
        XCTAssertEqual(parsed?.mapboxId, original.mapboxId)
        XCTAssertEqual(parsed?.latitude ?? 0, original.latitude ?? 0, accuracy: 0.0001)
        XCTAssertEqual(parsed?.longitude ?? 0, original.longitude ?? 0, accuracy: 0.0001)
    }

    func testRoundTrip_NilOptionals() {
        let original = ShareablePlace(
            id: "Z", name: "Plain", address: nil, city: nil,
            mapboxId: nil, latitude: nil, longitude: nil
        )
        guard let url = original.deepLinkURL else {
            XCTFail("deepLinkURL should not be nil")
            return
        }
        let parsed = ShareablePlace.from(url: url)

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.id, "Z")
        XCTAssertEqual(parsed?.name, "Plain")
        XCTAssertNil(parsed?.address)
        XCTAssertNil(parsed?.city)
        XCTAssertNil(parsed?.mapboxId)
        XCTAssertNil(parsed?.latitude)
        XCTAssertNil(parsed?.longitude)
    }

    // MARK: - Codable

    func testCodableRoundTrip() throws {
        let original = fullPlace()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ShareablePlace.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.address, original.address)
        XCTAssertEqual(decoded.city, original.city)
        XCTAssertEqual(decoded.mapboxId, original.mapboxId)
        XCTAssertEqual(decoded.latitude, original.latitude)
        XCTAssertEqual(decoded.longitude, original.longitude)
    }
}
