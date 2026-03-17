//
//  TripTests.swift
//  locTests
//
//  Tests for Trip date parsing, formatting, numberOfDays, and Codable round-trip.
//

import XCTest
@testable import loc

final class TripTests: XCTestCase {

    // MARK: - Helpers

    /// Decodes a Trip from a JSON dictionary.
    private func decodeTripJSON(_ dict: [String: Any]) throws -> Trip {
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(Trip.self, from: data)
    }

    /// Returns a minimal valid JSON dictionary for a Trip.
    private func minimalTripJSON(
        id: String = "trip-1",
        name: String = "Test Trip",
        ownerId: String = "owner-1",
        startDate: String = "2026-06-01",
        endDate: String = "2026-06-05"
    ) -> [String: Any] {
        [
            "id": id,
            "name": name,
            "owner_id": ownerId,
            "start_date": startDate,
            "end_date": endDate
        ]
    }

    /// Creates a Date from "yyyy-MM-dd" in UTC.
    private func utcDate(_ string: String) -> Date {
        Trip.parseDate(string)!
    }

    // MARK: - parseDate

    func testParseDate_ValidFormat() {
        let date = Trip.parseDate("2026-03-15")
        XCTAssertNotNil(date)

        let calendar = Calendar.current
        let components = calendar.dateComponents(in: TimeZone(identifier: "UTC")!, from: date!)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 3)
        XCTAssertEqual(components.day, 15)
    }

    func testParseDate_InvalidString() {
        XCTAssertNil(Trip.parseDate("not-a-date"))
        XCTAssertNil(Trip.parseDate(""))
        XCTAssertNil(Trip.parseDate("03/15/2026"))
        XCTAssertNil(Trip.parseDate("2026-13-01")) // invalid month
        XCTAssertNil(Trip.parseDate("2026-02-30")) // invalid day
    }

    func testParseDate_LeapYear() {
        XCTAssertNotNil(Trip.parseDate("2024-02-29"))
        XCTAssertNil(Trip.parseDate("2025-02-29"))
    }

    func testParseDate_YearBoundaries() {
        XCTAssertNotNil(Trip.parseDate("2026-01-01"))
        XCTAssertNotNil(Trip.parseDate("2026-12-31"))
    }

    // MARK: - formatDate

    func testFormatDate_ProducesCorrectString() {
        let date = utcDate("2026-07-04")
        let formatted = Trip.formatDate(date)
        XCTAssertEqual(formatted, "2026-07-04")
    }

    func testFormatDate_RoundTripsWithParseDate() {
        let original = "2026-11-25"
        let date = Trip.parseDate(original)!
        let formatted = Trip.formatDate(date)
        XCTAssertEqual(formatted, original)
    }

    // MARK: - numberOfDays

    func testNumberOfDays_SameDayTrip() throws {
        let trip = try decodeTripJSON(minimalTripJSON(startDate: "2026-06-01", endDate: "2026-06-01"))
        XCTAssertEqual(trip.numberOfDays, 1)
    }

    func testNumberOfDays_MultiDay() throws {
        let trip = try decodeTripJSON(minimalTripJSON(startDate: "2026-06-01", endDate: "2026-06-05"))
        XCTAssertEqual(trip.numberOfDays, 5)
    }

    func testNumberOfDays_MultiMonth() throws {
        let trip = try decodeTripJSON(minimalTripJSON(startDate: "2026-06-28", endDate: "2026-07-03"))
        XCTAssertEqual(trip.numberOfDays, 6)
    }

    func testNumberOfDays_CrossYear() throws {
        let trip = try decodeTripJSON(minimalTripJSON(startDate: "2025-12-30", endDate: "2026-01-02"))
        XCTAssertEqual(trip.numberOfDays, 4)
    }

    // MARK: - startDate / endDate Computed Properties

    func testStartDateEndDate_ParseFromRawStrings() throws {
        let trip = try decodeTripJSON(minimalTripJSON(startDate: "2026-08-10", endDate: "2026-08-15"))

        let calendar = Calendar.current
        let startComponents = calendar.dateComponents(in: TimeZone(identifier: "UTC")!, from: trip.startDate)
        XCTAssertEqual(startComponents.year, 2026)
        XCTAssertEqual(startComponents.month, 8)
        XCTAssertEqual(startComponents.day, 10)

        let endComponents = calendar.dateComponents(in: TimeZone(identifier: "UTC")!, from: trip.endDate)
        XCTAssertEqual(endComponents.year, 2026)
        XCTAssertEqual(endComponents.month, 8)
        XCTAssertEqual(endComponents.day, 15)
    }

    // MARK: - Codable

    func testDecodeMinimalTrip() throws {
        let trip = try decodeTripJSON(minimalTripJSON())

        XCTAssertEqual(trip.id, "trip-1")
        XCTAssertEqual(trip.name, "Test Trip")
        XCTAssertEqual(trip.ownerId, "owner-1")
        XCTAssertNil(trip.coverImage)
        XCTAssertNil(trip.createdAt)
        XCTAssertNil(trip.updatedAt)
    }

    func testDecodeAllFields() throws {
        var json = minimalTripJSON()
        json["cover_image"] = "https://example.com/cover.jpg"
        json["created_at"] = "2026-01-01T00:00:00Z"
        json["updated_at"] = "2026-01-15T12:00:00Z"

        let trip = try decodeTripJSON(json)

        XCTAssertEqual(trip.coverImage, "https://example.com/cover.jpg")
        XCTAssertEqual(trip.createdAt, "2026-01-01T00:00:00Z")
        XCTAssertEqual(trip.updatedAt, "2026-01-15T12:00:00Z")
    }

    func testEncodeDecodeRoundTrip() throws {
        let original = Trip(
            id: "rt-1",
            name: "Round Trip",
            ownerId: "owner-rt",
            startDate: utcDate("2026-04-01"),
            endDate: utcDate("2026-04-10"),
            coverImage: "https://example.com/img.jpg",
            createdAt: "2026-01-01",
            updatedAt: "2026-02-01"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Trip.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.ownerId, original.ownerId)
        XCTAssertEqual(decoded.numberOfDays, original.numberOfDays)
        XCTAssertEqual(decoded.coverImage, original.coverImage)
        XCTAssertEqual(Trip.formatDate(decoded.startDate), Trip.formatDate(original.startDate))
        XCTAssertEqual(Trip.formatDate(decoded.endDate), Trip.formatDate(original.endDate))
    }

    // MARK: - Equatable

    func testEquatable_SameTrips() throws {
        let json = minimalTripJSON()
        let a = try decodeTripJSON(json)
        let b = try decodeTripJSON(json)
        XCTAssertEqual(a, b)
    }

    func testEquatable_DifferentName() throws {
        let a = try decodeTripJSON(minimalTripJSON(name: "Trip A"))
        let b = try decodeTripJSON(minimalTripJSON(name: "Trip B"))
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Memberwise Initializer

    func testMemberwiseInit_FormatsDateStrings() {
        let trip = Trip(
            id: "init-1",
            name: "Init Trip",
            ownerId: "owner",
            startDate: utcDate("2026-05-01"),
            endDate: utcDate("2026-05-07")
        )

        XCTAssertEqual(trip.numberOfDays, 7)
        XCTAssertEqual(Trip.formatDate(trip.startDate), "2026-05-01")
        XCTAssertEqual(Trip.formatDate(trip.endDate), "2026-05-07")
    }
}
