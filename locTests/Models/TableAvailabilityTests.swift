//
//  TableAvailabilityTests.swift
//  locTests
//
//  Tests for "Find a table": request building, window defaults and response decoding.
//

import XCTest
@testable import loc

final class TableAvailabilityTests: XCTestCase {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0, _ second: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
    }

    private func decode(_ json: String) throws -> TableAvailabilityResponse {
        try JSONDecoder().decode(TableAvailabilityResponse.self, from: Data(json.utf8))
    }

    // MARK: - Request building

    func testRequestBodyUsesBackendKeysAndFormats() throws {
        let request = TableAvailabilityRequest.make(
            partySize: 4, date: date(2026, 3, 7, 15), window: TableSearchWindow(startMinutes: 19 * 60 + 30, endMinutes: 22 * 60 + 30), calendar: calendar)
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any]
        XCTAssertEqual(object?["party_size"] as? Int, 4)
        XCTAssertEqual(object?["date"] as? String, "2026-03-07")
        XCTAssertEqual(object?["time_start"] as? String, "19:30")
        XCTAssertEqual(object?["time_end"] as? String, "22:30")
        XCTAssertEqual(object?.count, 4)
    }

    func testURLRequestTargetsListAvailabilityWithAuth() throws {
        let body = TableAvailabilityRequest(partySize: 2, date: "2026-03-07", timeStart: "19:00", timeEnd: "22:30")
        let request = try TableAvailabilityService.makeRequest(baseURL: "https://api.example.com", listId: "abc 123", body: body, accessToken: "tok")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/lists/abc%20123/availability")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer tok")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertNotNil(request.httpBody)
    }

    func testURLRequestWithoutTokenOmitsAuthorization() throws {
        let body = TableAvailabilityRequest(partySize: 2, date: "2026-03-07", timeStart: "19:00", timeEnd: "22:30")
        let request = try TableAvailabilityService.makeRequest(baseURL: "https://x.test", listId: "l1", body: body, accessToken: nil)
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
    }

    func testStatusCodeMapping() {
        XCTAssertNil(TableAvailabilityService.error(forStatusCode: 200))
        XCTAssertEqual(TableAvailabilityService.error(forStatusCode: 404), .unavailable)
        XCTAssertEqual(TableAvailabilityService.error(forStatusCode: 501), .unavailable)
        XCTAssertEqual(TableAvailabilityService.error(forStatusCode: 500), .failed)
        XCTAssertEqual(TableAvailabilityService.error(forStatusCode: 401), .failed)
    }

    func testClockAndMinutesRoundTrip() {
        XCTAssertEqual(TableTimeFormat.clockString(minutes: 9 * 60 + 5), "09:05")
        XCTAssertEqual(TableTimeFormat.clockString(minutes: 5000), "23:59")
        XCTAssertEqual(TableTimeFormat.minutes(fromClock: "19:30"), 19 * 60 + 30)
        XCTAssertNil(TableTimeFormat.minutes(fromClock: "25:00"))
        XCTAssertNil(TableTimeFormat.minutes(fromClock: "noon"))
    }

    // MARK: - Window defaults

    func testNextHalfHourRoundsUp() {
        XCTAssertEqual(TableSearchWindow.nextHalfHour(after: date(2026, 3, 7, 18, 10), calendar: calendar), 18 * 60 + 30)
        XCTAssertEqual(TableSearchWindow.nextHalfHour(after: date(2026, 3, 7, 18, 31), calendar: calendar), 19 * 60)
        XCTAssertEqual(TableSearchWindow.nextHalfHour(after: date(2026, 3, 7, 18, 30), calendar: calendar), 18 * 60 + 30)
        XCTAssertEqual(TableSearchWindow.nextHalfHour(after: date(2026, 3, 7, 18, 30, 5), calendar: calendar), 19 * 60)
    }

    func testTonightDefaultsToTodayNextHalfHourThrough1030() {
        let selection = TableSearchSelection.tonight(now: date(2026, 3, 7, 18, 10), calendar: calendar)
        XCTAssertEqual(selection.date, date(2026, 3, 7))
        XCTAssertEqual(selection.window, TableSearchWindow(startMinutes: 18 * 60 + 30, endMinutes: 22 * 60 + 30))
        XCTAssertTrue(selection.window.isValid)
    }

    func testTonightTooLateFallsBackToTomorrowEvening() {
        let selection = TableSearchSelection.tonight(now: date(2026, 3, 7, 22, 45), calendar: calendar)
        XCTAssertEqual(selection.date, date(2026, 3, 8))
        XCTAssertEqual(selection.window.startMinutes, 17 * 60)
        XCTAssertTrue(selection.window.isValid)
    }

    func testTomorrowPreset() {
        let selection = TableSearchSelection.tomorrow(now: date(2026, 3, 31, 12), calendar: calendar)
        XCTAssertEqual(selection.date, date(2026, 4, 1))
        XCTAssertEqual(selection.window, TableSearchWindow(startMinutes: 17 * 60, endMinutes: 22 * 60 + 30))
    }

    // MARK: - Response decoding

    func testDecodeFullResponse() throws {
        let response = try decode("""
        {"checked":3,"unsupported_count":2,"places":[
          {"place_id":"P1","provider":"resy","booking_url":"https://resy.com/x","status":"available",
           "slots":[{"time":"20:00","type":"Dining Room"},{"time":"19:15","type":null}]},
          {"place_id":"P2","provider":"resy","slots":[],"booking_url":null,"status":"none"},
          {"place_id":"P3","provider":"resy","slots":[],"status":"error"}]}
        """)
        XCTAssertEqual(response.checked, 3)
        XCTAssertEqual(response.unsupportedCount, 2)
        XCTAssertEqual(response.placesWithTables.map(\.placeId), ["P1"])
        XCTAssertEqual(response.places[0].sortedSlots.map(\.time), ["19:15", "20:00"])
        XCTAssertEqual(response.places[0].bookingDestination?.host, "resy.com")
        XCTAssertEqual(response.providerName, "Resy")
        XCTAssertFalse(response.allChecksFailed)
    }

    func testDecodeToleratesMissingFieldsAndUnknownStatus() throws {
        let response = try decode(#"{"places":[{"place_id":"p","status":"weird"}]}"#)
        XCTAssertEqual(response.checked, 1)
        XCTAssertEqual(response.unsupportedCount, 0)
        XCTAssertEqual(response.places[0].status, .unknown)
        XCTAssertFalse(response.places[0].hasTables)
    }

    func testAvailableWithoutSlotsHasNoTables() throws {
        let response = try decode(#"{"checked":1,"places":[{"place_id":"p","status":"available","slots":[]}]}"#)
        XCTAssertTrue(response.placesWithTables.isEmpty)
    }

    func testAllChecksFailedOnlyWhenEveryPlaceErrored() throws {
        let failed = try decode(#"{"checked":2,"places":[{"place_id":"a","status":"error"},{"place_id":"b","status":"error"}]}"#)
        XCTAssertTrue(failed.allChecksFailed)
        let empty = try decode(#"{"checked":0,"places":[],"unsupported_count":4}"#)
        XCTAssertFalse(empty.allChecksFailed)
    }

    func testNonHTTPBookingURLIsRejected() {
        let place = PlaceTableAvailability(placeId: "p", bookingURL: "javascript:alert(1)", status: .available)
        XCTAssertNil(place.bookingDestination)
    }
}
