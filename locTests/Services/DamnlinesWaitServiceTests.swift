//
//  DamnlinesWaitServiceTests.swift
//  locTests
//

import XCTest
@testable import loc

final class DamnlinesWaitServiceTests: XCTestCase {
    private let fixture = Data(DamnlinesFixture.indexJSON.utf8)

    /// Returns parsed info for a Mesa place id using the fixture index.
    private func info(forPlaceId id: String) -> DamnlinesWaitInfo? {
        DamnlinesPlaceMap.slug(forPlaceId: id).flatMap { DamnlinesWaitService.parse(fixture, slug: $0) }
    }

    func testParseLindustrie() throws {
        let result = try XCTUnwrap(DamnlinesWaitService.parse(fixture, slug: "lindustrie-pizzeria"))
        XCTAssertEqual(result.venueName, "L'industrie Pizzeria")
        XCTAssertEqual(result.pageURL.absoluteString, "https://damnlines.com/camera/lindustrie-pizzeria")
        XCTAssertEqual(result.peakDay, "Saturday")
        XCTAssertEqual(result.peakHourLocal, "5 PM")
        XCTAssertEqual(result.peakWaitMinutes, 26)
    }

    func testParseUnknownSlugReturnsNil() {
        XCTAssertNil(DamnlinesWaitService.parse(fixture, slug: "nope"))
    }

    func testParseGarbageReturnsNil() {
        XCTAssertNil(DamnlinesWaitService.parse(Data("{".utf8), slug: "golden-diner"))
    }

    func testMappedPlacesResolve() {
        let ids = [
            "B9A81082-EA4E-43AB-B7BE-5FCF178C31FD", "B89AA028-535D-44E8-ADEF-1BAFB36F4715",
            "87BF7B40-9FC2-4BAA-A714-F0E61B6BF278", "2E8C9271-38EE-4DCD-90F9-4DA888CBC234",
            "0255615F-4AF1-4EC0-A771-8804831F49DC"
        ]
        for id in ids { XCTAssertNotNil(info(forPlaceId: id), id) }
    }

    func testUnmappedPlacesDoNotResolve() {
        let ids = [
            "FA19FDDC-C44C-4105-812E-1663D9ADBE70", "F2DCD3BE-B33D-463E-9B3D-80787AA50C28",
            "FE04D4B7-C666-4D8A-8FB2-03A1A4635AA9", "00000000-0000-0000-0000-000000000000", ""
        ]
        for id in ids { XCTAssertNil(DamnlinesPlaceMap.slug(forPlaceId: id), id) }
    }

    func testPlaceIdMatchIsCaseInsensitive() {
        XCTAssertEqual(DamnlinesPlaceMap.slug(forPlaceId: "b9a81082-ea4e-43ab-b7be-5fcf178c31fd"), "lindustrie-pizzeria")
    }

    func testSummaryText() throws {
        let result = try XCTUnwrap(DamnlinesWaitService.parse(fixture, slug: "lindustrie-pizzeria"))
        XCTAssertEqual(result.summaryText, "Usually ~\(result.averageWaitMinutes) min wait · peaks ~26 min Sat 5 PM")
    }

    func testDayAbbreviation() {
        XCTAssertEqual(DamnlinesWaitInfo.abbreviate(day: "Friday"), "Fri")
        XCTAssertEqual(DamnlinesWaitInfo.abbreviate(day: "Thursday"), "Thu")
        XCTAssertEqual(DamnlinesWaitInfo.abbreviate(day: "Weekend"), "Weekend")
    }
}
