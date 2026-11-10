//
//  ListPlaceCountTests.swift
//  locTests
//
//  Tests for list-id normalization and the displayed place-count resolver.
//

import XCTest
@testable import loc

final class ListPlaceCountTests: XCTestCase {

    /// Upper and lower case UUID strings collapse to the same key.
    func testNormalizedIdIgnoresUUIDCasing() {
        let upper = "A1B2C3D4-E5F6-7890-ABCD-EF1234567890"
        let lower = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
        XCTAssertEqual(ListPlaceCount.normalizedId(upper), ListPlaceCount.normalizedId(lower))
        XCTAssertEqual(ListPlaceCount.normalizedId(upper), lower)
    }

    /// Non-UUID strings are still lowercased so lookups stay consistent.
    func testNormalizedIdLowercasesNonUUID() {
        XCTAssertEqual(ListPlaceCount.normalizedId("MyList"), "mylist")
    }

    /// When metadata says 1 but 6 places are already loaded, show 6.
    func testDisplayedCountNeverBelowLoadedPlaces() {
        let count = ListPlaceCount.displayed(cached: 1, metadata: 1, loaded: 6)
        XCTAssertEqual(count, 6)
    }

    /// When metadata says 20 and only the first page of 6 is loaded, keep showing 20.
    func testDisplayedCountKeepsMetadataTotalWhilePaging() {
        let count = ListPlaceCount.displayed(cached: 20, metadata: 20, loaded: 6)
        XCTAssertEqual(count, 20)
    }

    /// A missing cache falls back to metadata, then to loaded.
    func testDisplayedCountFallsBackToMetadataThenLoaded() {
        XCTAssertEqual(ListPlaceCount.displayed(cached: nil, metadata: 4, loaded: 0), 4)
        XCTAssertEqual(ListPlaceCount.displayed(cached: nil, metadata: 0, loaded: 3), 3)
    }

    /// After an optimistic add, the incremented cache wins over a stale snapshot.
    func testDisplayedCountUsesIncrementedCache() {
        XCTAssertEqual(ListPlaceCount.displayed(cached: 7, metadata: 1, loaded: 7), 7)
    }
}
