//
//  LightweightTripTests.swift
//  locTests
//
//  Tests for LightweightTrip Codable decoding, dateRangeString, numberOfDays, and id alias.
//

import XCTest
@testable import loc

final class LightweightTripTests: XCTestCase {

    // MARK: - Helpers

    /// Decodes a LightweightTrip from a JSON dictionary.
    private func decodeTripJSON(_ dict: [String: Any]) throws -> LightweightTrip {
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(LightweightTrip.self, from: data)
    }

    /// Returns a minimal valid JSON dictionary for a LightweightTrip.
    private func minimalJSON(
        tripId: String = "lt-1",
        name: String = "Test Trip",
        startDate: String = "2026-06-01",
        endDate: String = "2026-06-05",
        placeCount: Int = 3
    ) -> [String: Any] {
        [
            "trip_id": tripId,
            "name": name,
            "start_date": startDate,
            "end_date": endDate,
            "place_count": placeCount
        ]
    }

    // MARK: - Basic Decoding

    func testDecodeMinimal() throws {
        let trip = try decodeTripJSON(minimalJSON())

        XCTAssertEqual(trip.tripId, "lt-1")
        XCTAssertEqual(trip.name, "Test Trip")
        XCTAssertEqual(trip.placeCount, 3)
        XCTAssertNil(trip.coverImage)
        XCTAssertNil(trip.ownerId)
        XCTAssertNil(trip.ownerName)
        XCTAssertNil(trip.collaboratorCount)
        XCTAssertNil(trip.collaboratorPhotos)
        XCTAssertNil(trip.isShared)
    }

    func testDecodeAllFields() throws {
        var json = minimalJSON()
        json["cover_image"] = "https://example.com/cover.jpg"
        json["owner_id"] = "owner-1"
        json["owner_name"] = "Alice"
        json["collaborator_count"] = 2
        json["collaborator_photos"] = ["https://photo1.jpg", "https://photo2.jpg"]
        json["is_shared"] = true

        let trip = try decodeTripJSON(json)

        XCTAssertEqual(trip.coverImage, "https://example.com/cover.jpg")
        XCTAssertEqual(trip.ownerId, "owner-1")
        XCTAssertEqual(trip.ownerName, "Alice")
        XCTAssertEqual(trip.collaboratorCount, 2)
        XCTAssertEqual(trip.collaboratorPhotos, ["https://photo1.jpg", "https://photo2.jpg"])
        XCTAssertEqual(trip.isShared, true)
    }

    // MARK: - id Alias

    func testId_ReturnsTripId() throws {
        let trip = try decodeTripJSON(minimalJSON(tripId: "my-trip-id"))
        XCTAssertEqual(trip.id, "my-trip-id")
        XCTAssertEqual(trip.id, trip.tripId)
    }

    // MARK: - numberOfDays

    func testNumberOfDays_SameDay() throws {
        let trip = try decodeTripJSON(minimalJSON(startDate: "2026-06-01", endDate: "2026-06-01"))
        XCTAssertEqual(trip.numberOfDays, 1)
    }

    func testNumberOfDays_MultiDay() throws {
        let trip = try decodeTripJSON(minimalJSON(startDate: "2026-06-01", endDate: "2026-06-05"))
        XCTAssertEqual(trip.numberOfDays, 5)
    }

    func testNumberOfDays_CrossMonth() throws {
        let trip = try decodeTripJSON(minimalJSON(startDate: "2026-06-28", endDate: "2026-07-03"))
        XCTAssertEqual(trip.numberOfDays, 6)
    }

    // MARK: - dateRangeString

    func testDateRangeString_SameYear() throws {
        let trip = try decodeTripJSON(minimalJSON(startDate: "2026-01-15", endDate: "2026-01-20"))
        XCTAssertEqual(trip.dateRangeString, "Jan 15 - Jan 20, 2026")
    }

    func testDateRangeString_SameYearDifferentMonths() throws {
        let trip = try decodeTripJSON(minimalJSON(startDate: "2026-03-25", endDate: "2026-04-02"))
        XCTAssertEqual(trip.dateRangeString, "Mar 25 - Apr 2, 2026")
    }

    func testDateRangeString_CrossYear() throws {
        let trip = try decodeTripJSON(minimalJSON(startDate: "2025-12-25", endDate: "2026-01-05"))
        XCTAssertEqual(trip.dateRangeString, "Dec 25, 2025 - Jan 5, 2026")
    }

    func testDateRangeString_SingleDay() throws {
        let trip = try decodeTripJSON(minimalJSON(startDate: "2026-07-04", endDate: "2026-07-04"))
        XCTAssertEqual(trip.dateRangeString, "Jul 4 - Jul 4, 2026")
    }

    // MARK: - Codable Round Trip

    func testEncodeDecodeRoundTrip() throws {
        var json = minimalJSON(tripId: "rt-lt", name: "Round Trip")
        json["cover_image"] = "https://example.com/rt.jpg"
        json["collaborator_count"] = 5
        json["is_shared"] = false

        let original = try decodeTripJSON(json)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LightweightTrip.self, from: data)

        XCTAssertEqual(decoded.tripId, original.tripId)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.placeCount, original.placeCount)
        XCTAssertEqual(decoded.coverImage, original.coverImage)
        XCTAssertEqual(decoded.collaboratorCount, original.collaboratorCount)
        XCTAssertEqual(decoded.isShared, original.isShared)
        XCTAssertEqual(decoded.numberOfDays, original.numberOfDays)
    }

    // MARK: - Equatable

    func testEquatable() throws {
        let json = minimalJSON()
        let a = try decodeTripJSON(json)
        let b = try decodeTripJSON(json)
        XCTAssertEqual(a, b)
    }
}
