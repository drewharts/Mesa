//
//  MapIdDiffTests.swift
//  locTests
//
//  Tests for MapIdDiff add/remove/keep computation.
//

import XCTest
@testable import loc

final class MapIdDiffTests: XCTestCase {

    func testDiffSplitsAddedRemovedKept() {
        let diff = MapIdDiff(old: ["a", "b"], new: ["b", "c"])
        XCTAssertEqual(diff.removed, ["a"])
        XCTAssertEqual(diff.added, ["c"])
        XCTAssertEqual(diff.kept, ["b"])
        XCTAssertFalse(diff.isEmpty)
    }

    func testIdenticalSetsAreEmpty() {
        XCTAssertTrue(MapIdDiff(old: ["a"], new: ["a"]).isEmpty)
    }

    func testBothEmptyIsEmpty() {
        XCTAssertTrue(MapIdDiff(old: [], new: []).isEmpty)
    }
}
