//
//  ListTypeFilterViewModelTests.swift
//  locTests
//
//  Tests chip selection loading: unloaded matches are fetched (with a loading state), id case differences
//  do not hide matches, and the failure state is reported only when matches stay unloaded.
//

import XCTest
@testable import loc

@MainActor
final class ListTypeFilterViewModelTests: XCTestCase {

    private func place(_ id: String, _ name: String, categories: [String]) -> LightweightPlace {
        LightweightPlace(place_id: id, name: name, latest_review_photo: nil, categories: categories)
    }

    /// A view model whose whole-list tag source is the given places (ids may differ in case from loaded ones).
    private func makeViewModel(source: [LightweightPlace]) async -> ListTypeFilterViewModel {
        let vm = ListTypeFilterViewModel(tagSourceLoader: { _ in source }, cache: ListTagSourceCache())
        await vm.refreshTagSource(listId: "list", loaded: [])
        return vm
    }

    /// Mutable loaded-places holder shared by the read and load-all closures.
    private final class Loaded { var places: [LightweightPlace] = [] }

    private var pizzaChip: ListTypeChip { ListTypeChip(tag: "Pizza", title: "Pizza") }

    private var source: [LightweightPlace] {
        [place("AAA", "Joe's", categories: ["pizza_restaurant"]),
         place("BBB", "Lucali", categories: ["pizza_restaurant"]),
         place("CCC", "Dante", categories: ["bar"]),
         place("DDD", "Attaboy", categories: ["bar"])]
    }

    func testSelectingChipLoadsUnloadedMatches() async {
        let vm = await makeViewModel(source: source)
        vm.select(pizzaChip)
        let loaded = Loaded()
        loaded.places = [place("ccc", "Dante", categories: ["bar"])]
        var loadAllCalls = 0
        await vm.loadMatchesIfNeeded(loaded: { loaded.places }, loadAll: {
            loadAllCalls += 1
            loaded.places += [self.place("aaa", "Joe's", categories: ["pizza_restaurant"]),
                              self.place("bbb", "Lucali", categories: ["pizza_restaurant"])]
        })
        XCTAssertEqual(loadAllCalls, 1)
        XCTAssertFalse(vm.isLoadingMatches)
        XCTAssertFalse(vm.matchesLoadFailed)
        XCTAssertEqual(vm.visiblePlaces(from: loaded.places).count, 2)
    }

    func testIdCaseDifferenceDoesNotHideMatches() async {
        let vm = await makeViewModel(source: source)
        vm.select(pizzaChip)
        let loaded = [place("aaa", "Joe's", categories: ["pizza_restaurant"])]
        XCTAssertEqual(vm.visiblePlaces(from: loaded).map(\.place_id), ["aaa"])
        XCTAssertEqual(vm.unloadedMatchIds(loaded: loaded), ["bbb"])
    }

    func testFailedLoadReportsFailureAfterRetry() async {
        let vm = await makeViewModel(source: source)
        vm.select(pizzaChip)
        var calls = 0
        await vm.loadMatchesIfNeeded(loaded: { [] }, loadAll: { calls += 1 })
        XCTAssertEqual(calls, 2)
        XCTAssertTrue(vm.matchesLoadFailed)
        XCTAssertFalse(vm.isLoadingMatches)
    }

    func testBeginLoadingMatchesShowsLoadingBeforeTaskRuns() async {
        let vm = await makeViewModel(source: source)
        vm.select(pizzaChip)
        vm.beginLoadingMatchesIfNeeded(loaded: [])
        XCTAssertTrue(vm.isLoadingMatches)
    }

    func testNothingToLoadWhenAllMatchesAreLoaded() async {
        let vm = await makeViewModel(source: source)
        vm.select(pizzaChip)
        let loaded = source
        var calls = 0
        await vm.loadMatchesIfNeeded(loaded: { loaded }, loadAll: { calls += 1 })
        XCTAssertEqual(calls, 0)
        XCTAssertFalse(vm.isLoadingMatches)
    }
}
