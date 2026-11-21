//
//  TableSearchPlannerTests.swift
//  locTests
//
//  Tests for streamed "Find a table": chunking, scope selection, merge/de-dup, progress and the five-minute cache.
//

import XCTest
@testable import loc

final class TableSearchPlannerTests: XCTestCase {

    private func place(_ id: String, time: String? = nil, status: TableAvailabilityStatus = .available) -> PlaceTableAvailability {
        PlaceTableAvailability(placeId: id, provider: "resy", slots: time.map { [TableSlot(time: $0, type: nil)] } ?? [], status: status)
    }

    private func response(_ places: [PlaceTableAvailability], checked: Int? = nil) -> TableAvailabilityResponse {
        TableAvailabilityResponse(checked: checked ?? places.count, places: places)
    }

    private func ids(_ count: Int) -> [String] { (0..<count).map { String(format: "p%03d", $0) } }

    // MARK: - Chunking

    func testChunksSplitIntoTens() {
        let chunks = TableSearchPlanner.chunks(ids(23))
        XCTAssertEqual(chunks.map(\.count), [10, 10, 3])
        XCTAssertEqual(chunks.flatMap { $0 }, ids(23))
    }

    func testChunksExactMultipleAndEmpty() {
        XCTAssertEqual(TableSearchPlanner.chunks(ids(20)).count, 2)
        XCTAssertTrue(TableSearchPlanner.chunks([]).isEmpty)
        XCTAssertTrue(TableSearchPlanner.chunks(ids(3), size: 0).isEmpty)
    }

    // MARK: - Scope

    func testScopeUsesChipIdsWhenActive() {
        let scope = TableSearchPlanner.scope(scopeIds: ["B", "a"], label: "Sushi", allIds: ["a", "b", "c"])
        XCTAssertEqual(scope.placeIds, ["a", "b"])
        XCTAssertEqual(scope.label, "Sushi")
    }

    func testScopeFallsBackToWholeListWithoutLabel() {
        let scope = TableSearchPlanner.scope(scopeIds: nil, label: "Sushi", allIds: ["b", "A", "c"])
        XCTAssertEqual(scope.placeIds, ["a", "b", "c"])
        XCTAssertNil(scope.label)
    }

    func testEmptyChipScopeStaysEmpty() {
        XCTAssertTrue(TableSearchPlanner.scope(scopeIds: [], label: "Sushi", allIds: ["a"]).isEmpty)
    }

    // MARK: - Merge

    func testMergeDeduplicatesKeepingFirstArrival() {
        let merged = TableSearchPlanner.merge([place("a", time: "19:00"), place("b", time: "20:00")],
                                              with: [place("B", time: "21:00"), place("c", time: "18:00")])
        XCTAssertEqual(merged.map(\.id), ["a", "b", "c"])
        XCTAssertEqual(merged[1].slots.first?.time, "20:00")
    }

    func testMergeReplacesUncheckedDuplicate() {
        let merged = TableSearchPlanner.merge([place("a", status: .error)], with: [place("a", time: "19:00")])
        XCTAssertEqual(merged.count, 1)
        XCTAssertTrue(merged[0].hasTables)
    }

    func testOrderedBySoonestIsStable() {
        let ordered = TableSearchPlanner.orderedBySoonest([place("a", time: "21:00"), place("b", time: "19:00"), place("c", time: "19:00"), place("d", status: .noTables)])
        XCTAssertEqual(ordered.map(\.id), ["b", "c", "a", "d"])
    }

    // MARK: - Accumulator

    func testAccumulatorTracksProgressAndDedupsAcrossChunks() {
        var acc = TableSearchAccumulator(total: 15, chunkCount: 2)
        acc.applySuccess(chunk: ids(10), response: response([place("p000", time: "19:00"), place("p001", status: .noTables)]))
        XCTAssertEqual(acc.processedPlaces, 10)
        XCTAssertFalse(acc.isComplete)
        // A backend that ignores place_ids returns places outside the chunk, including repeats.
        acc.applySuccess(chunk: Array(ids(15).suffix(5)), response: response([place("p000", time: "19:00"), place("p012", time: "20:00")]))
        XCTAssertTrue(acc.isComplete)
        XCTAssertEqual(acc.processedPlaces, 15)
        XCTAssertEqual(acc.withTables.map(\.id), ["p000", "p012"])
        XCTAssertEqual(acc.fraction, 1)
    }

    func testFailedChunkDoesNotKillSearch() {
        var acc = TableSearchAccumulator(total: 20, chunkCount: 2)
        acc.applyFailure(chunk: ids(10))
        acc.applySuccess(chunk: Array(ids(20).suffix(10)), response: response([place("p015", time: "19:00")]))
        XCTAssertTrue(acc.isComplete)
        XCTAssertEqual(acc.failedChunks, 1)
        XCTAssertFalse(acc.allFailed)
        XCTAssertEqual(acc.withTables.count, 1)
    }

    func testAllChunksFailed() {
        var acc = TableSearchAccumulator(total: 10, chunkCount: 1)
        acc.applyFailure(chunk: ids(10))
        XCTAssertTrue(acc.allFailed)
    }

    func testStaleResultsShownUntilTheirChunkRefreshes() {
        var acc = TableSearchAccumulator(total: 10, chunkCount: 1, stale: [place("a", time: "19:00"), place("z", time: "20:00")])
        XCTAssertEqual(acc.withTables.map(\.id), ["a", "z"])
        acc.applySuccess(chunk: ["a", "b"], response: response([place("a", status: .noTables)]))
        XCTAssertEqual(acc.withTables.map(\.id), ["z"])
    }

    func testStaleResultsSurviveFailedRefresh() {
        var acc = TableSearchAccumulator(total: 1, chunkCount: 1, stale: [place("a", time: "19:00")])
        acc.applyFailure(chunk: ["a"])
        XCTAssertFalse(acc.allFailed)
        XCTAssertEqual(acc.withTables.map(\.id), ["a"])
    }

    // MARK: - Cache

    private func key(party: Int = 2, scope: [String] = ["a"]) -> TableSearchKey {
        let request = TableAvailabilityRequest(partySize: party, date: "2026-03-07", timeStart: "19:00", timeEnd: "22:30")
        return TableSearchKey(listId: "L", request: request, scope: TableSearchScope(placeIds: scope, label: nil))
    }

    func testCacheHitWithinFiveMinutesThenExpires() {
        var clock = Date(timeIntervalSince1970: 1_000)
        let cache = TableAvailabilityCache(now: { clock })
        let value = CachedTableSearch(places: [place("a", time: "19:00")], checked: 1, total: 1, providerName: "Resy")
        cache.store(value, for: key())
        clock = clock.addingTimeInterval(299)
        XCTAssertEqual(cache.value(for: key()), value)
        clock = clock.addingTimeInterval(2)
        XCTAssertNil(cache.value(for: key()))
    }

    func testCacheKeyDistinguishesPartyAndScope() {
        let cache = TableAvailabilityCache()
        cache.store(CachedTableSearch(places: [], checked: 0, total: 1, providerName: "Resy"), for: key())
        XCTAssertNil(cache.value(for: key(party: 4)))
        XCTAssertNil(cache.value(for: key(scope: ["a", "b"])))
        XCTAssertNotNil(cache.value(for: key()))
    }

    func testRequestEncodesPlaceIdsOnlyWhenRestricted() throws {
        let base = TableAvailabilityRequest(partySize: 2, date: "2026-03-07", timeStart: "19:00", timeEnd: "22:30")
        let plain = try JSONSerialization.jsonObject(with: JSONEncoder().encode(base)) as? [String: Any]
        XCTAssertNil(plain?["place_ids"])
        let restricted = try JSONSerialization.jsonObject(with: JSONEncoder().encode(base.restricted(to: ["a", "b"]))) as? [String: Any]
        XCTAssertEqual(restricted?["place_ids"] as? [String], ["a", "b"])
    }
}
