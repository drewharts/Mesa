//
//  ListPlaceOptimisticUpdateTests.swift
//  locTests
//
//  Tests for the optimistic add-to-list cache update, its rollback, and re-keying when the
//  server resolves a stale place id to the real one.
//

import XCTest
@testable import loc

final class ListPlaceOptimisticUpdateTests: XCTestCase {

    private func place(_ id: String, name: String = "Place") -> LightweightPlace {
        LightweightPlace(place_id: id, name: name, latest_review_photo: nil, added_by_user_id: "user-1")
    }

    func testApplyingAddInsertsAtFront() {
        let result = ListPlaceOptimisticUpdate.applyingAdd(place("NEW"), to: [place("A"), place("B")])
        XCTAssertTrue(result.didInsert)
        XCTAssertEqual(result.places.map(\.place_id), ["NEW", "A", "B"])
    }

    func testApplyingAddToEmptyCacheCreatesList() {
        let result = ListPlaceOptimisticUpdate.applyingAdd(place("NEW"), to: nil)
        XCTAssertTrue(result.didInsert)
        XCTAssertEqual(result.places.map(\.place_id), ["NEW"])
    }

    func testApplyingAddSkipsExistingIdIgnoringCase() {
        let result = ListPlaceOptimisticUpdate.applyingAdd(place("abc-1"), to: [place("ABC-1")])
        XCTAssertFalse(result.didInsert)
        XCTAssertEqual(result.places.count, 1)
    }

    func testRevertingAddRemovesOnlyThatPlace() {
        let places = ListPlaceOptimisticUpdate.revertingAdd(placeId: "new", from: [place("NEW"), place("A")])
        XCTAssertEqual(places.map(\.place_id), ["A"])
    }

    func testReplacingPlaceIdRekeysEntryAndKeepsPosition() {
        let places = ListPlaceOptimisticUpdate.replacingPlaceId("PHANTOM", with: "REAL", in: [place("PHANTOM", name: "Semma"), place("A")])
        XCTAssertEqual(places.map(\.place_id), ["REAL", "A"])
        XCTAssertEqual(places.first?.name, "Semma")
        XCTAssertEqual(places.first?.added_by_user_id, "user-1")
    }

    func testReplacingPlaceIdDropsDuplicateWhenRealIdAlreadyPresent() {
        let places = ListPlaceOptimisticUpdate.replacingPlaceId("PHANTOM", with: "REAL", in: [place("PHANTOM"), place("REAL")])
        XCTAssertEqual(places.map(\.place_id), ["REAL"])
    }

    func testCountAfterRollbackPrefersPreviousCount() {
        XCTAssertEqual(ListPlaceOptimisticUpdate.countAfterRollback(previousCount: 4, currentCount: 5), 4)
    }

    func testCountAfterRollbackDecrementsWhenNoPreviousCount() {
        XCTAssertEqual(ListPlaceOptimisticUpdate.countAfterRollback(previousCount: nil, currentCount: 5), 4)
        XCTAssertEqual(ListPlaceOptimisticUpdate.countAfterRollback(previousCount: nil, currentCount: 0), 0)
        XCTAssertEqual(ListPlaceOptimisticUpdate.countAfterRollback(previousCount: nil, currentCount: nil), 0)
    }
}
