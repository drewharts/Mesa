//
//  FoldedListsStoreTests.swift
//  locTests
//
//  Tests for the per-user, on-device record of folded lists (fold, restore, declined, prune).
//

import XCTest
@testable import loc

final class FoldedListsStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "FoldedListsStoreTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testFold_RecordsLowercasedIdsAndReturnsNewOnes() {
        let store = FoldedListsStore(userId: "U1", defaults: defaults)
        XCTAssertEqual(Set(store.fold(["AAA", "bbb"])), ["aaa", "bbb"])
        XCTAssertEqual(store.foldedIds, ["aaa", "bbb"])
        XCTAssertEqual(store.fold(["AAA", "ccc"]), ["ccc"])
        XCTAssertTrue(store.isFolded("AAA"))
    }

    func testRestore_UnfoldsAndNeverRefolds() {
        let store = FoldedListsStore(userId: "u1", defaults: defaults)
        store.fold(["a", "b"])
        store.restore(["a"])
        XCTAssertEqual(store.foldedIds, ["b"])
        XCTAssertEqual(store.declinedIds, ["a"])
        XCTAssertEqual(store.fold(["a", "c"]), ["c"])
        XCTAssertFalse(store.isFolded("a"))
    }

    func testState_IsPerUser() {
        FoldedListsStore(userId: "u1", defaults: defaults).fold(["a"])
        XCTAssertEqual(FoldedListsStore(userId: "u2", defaults: defaults).foldedIds, [])
        XCTAssertEqual(FoldedListsStore(userId: "U1", defaults: defaults).foldedIds, ["a"])
    }

    func testPrune_DropsListsThatNoLongerExist() {
        let store = FoldedListsStore(userId: "u1", defaults: defaults)
        store.fold(["a", "b"])
        store.prune(keeping: ["B", "z"])
        XCTAssertEqual(store.foldedIds, ["b"])
    }
}
