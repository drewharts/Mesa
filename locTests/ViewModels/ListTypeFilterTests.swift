//
//  ListTypeFilterTests.swift
//  locTests
//
//  Tests for the type chips inside a list: which chips show and what each one keeps.
//

import XCTest
@testable import loc

final class ListTypeFilterTests: XCTestCase {

    // MARK: - Helpers

    private func place(_ id: String, _ name: String, type: String?) -> LightweightPlace {
        LightweightPlace(place_id: id, name: name, latest_review_photo: nil, place_type: type)
    }

    private var mixed: [LightweightPlace] {
        [place("1", "Semma", type: "Indian restaurant"),
         place("2", "Dante", type: "Cocktail bar"),
         place("3", "Cafe Reggio", type: "Coffee shop"),
         place("4", "Strand", type: "Book store"),
         place("5", "Il Buco", type: "Italian restaurant")]
    }

    // MARK: - Chips

    func testChips_AllThenTypesPresentInFixedOrder() {
        let titles = ListTypeFilter.chips(for: mixed).map(\.title)
        XCTAssertEqual(titles, ["All", "Restaurants", "Bars", "Coffee & Sweets", "Shops"])
    }

    func testChips_HiddenWhenListHasOneType() {
        let onlyRestaurants = [place("1", "A", type: "Italian restaurant"), place("2", "B", type: "Thai restaurant")]
        XCTAssertTrue(ListTypeFilter.chips(for: onlyRestaurants).isEmpty)
        XCTAssertTrue(ListTypeFilter.chips(for: []).isEmpty)
    }

    func testChips_UnclassifiedPlacesFallUnderOther() {
        let places = [place("1", "A", type: "Italian restaurant"), place("2", "Mystery", type: nil)]
        XCTAssertEqual(ListTypeFilter.chips(for: places).map(\.title), ["All", "Restaurants", "Other"])
    }

    // MARK: - Filtering

    func testApply_NilKeepsEverything() {
        XCTAssertEqual(ListTypeFilter.apply(nil, to: mixed).count, 5)
    }

    func testApply_TypeKeepsOnlyThatType() {
        XCTAssertEqual(ListTypeFilter.apply(.restaurants, to: mixed).map(\.place_id), ["1", "5"])
        XCTAssertEqual(ListTypeFilter.apply(.bars, to: mixed).map(\.place_id), ["2"])
        XCTAssertTrue(ListTypeFilter.apply(.stays, to: mixed).isEmpty)
    }

    // MARK: - View model

    @MainActor
    func testViewModel_TappingSelectedChipReturnsToAll() {
        let vm = ListTypeFilterViewModel()
        let bars = ListTypeChip(type: .bars, title: "Bars")
        vm.select(bars)
        XCTAssertEqual(vm.visiblePlaces(from: mixed).map(\.place_id), ["2"])
        vm.select(bars)
        XCTAssertEqual(vm.visiblePlaces(from: mixed).count, 5)
    }

    @MainActor
    func testViewModel_SelectionForVanishedTypeShowsEverything() {
        let vm = ListTypeFilterViewModel()
        vm.select(ListTypeChip(type: .bars, title: "Bars"))
        let withoutBars = mixed.filter { $0.place_id != "2" }
        XCTAssertEqual(vm.visiblePlaces(from: withoutBars).count, 4)
    }
}
