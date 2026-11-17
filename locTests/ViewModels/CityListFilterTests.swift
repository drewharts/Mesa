//
//  CityListFilterTests.swift
//  locTests
//
//  Tests for a city's chip row (All, types, cuisines), what each chip keeps, and place ordering.
//

import XCTest
@testable import loc

final class CityListFilterTests: XCTestCase {

    // MARK: - Helpers

    private func place(_ id: String, _ type: SavedPlaceType, cuisine: String? = nil,
                       distance: Double? = nil, addedAt: Date? = nil) -> SavedLibraryPlace {
        SavedLibraryPlace(
            id: id, name: id, address: nil, latitude: nil, longitude: nil, city: "Tokyo", area: nil,
            type: type, cuisine: cuisine, isDinnerSpot: false, addedAt: addedAt,
            distanceMeters: distance, sources: [.list]
        )
    }

    private var sample: [SavedLibraryPlace] {
        [place("r1", .restaurants, cuisine: "Japanese"), place("r2", .restaurants, cuisine: "Japanese"),
         place("r3", .restaurants, cuisine: "Italian"), place("r4", .restaurants),
         place("b1", .bars), place("c1", .coffee), place("s1", .shops)]
    }

    // MARK: - Chips

    func testChips_AllThenTypesThenCuisines() {
        let chips = CityListFilter.chips(for: sample)
        XCTAssertEqual(chips.map(\.title), ["All", "Restaurants", "Bars", "Coffee & Sweets", "Shops", "Japanese", "Italian"])
        XCTAssertEqual(chips.map(\.count), [7, 4, 1, 1, 1, 2, 1])
        XCTAssertEqual(chips.first?.kind, .all)
    }

    func testChips_OnlyTypesPresent() {
        let chips = CityListFilter.chips(for: [place("c1", .coffee), place("c2", .coffee)])
        XCTAssertEqual(chips.map(\.title), ["All", "Coffee & Sweets"])
    }

    func testChips_EmptyCityHasJustAll() {
        XCTAssertEqual(CityListFilter.chips(for: []).map(\.title), ["All"])
    }

    func testChips_CuisineIgnoredOutsideRestaurants() {
        XCTAssertEqual(CityListFilter.cuisineCounts(in: [place("b1", .bars, cuisine: "Japanese")]).count, 0)
    }

    func testChips_CuisineChipsAreCapped() {
        let many = (0..<20).map { place("r\($0)", .restaurants, cuisine: "Cuisine \($0)") }
        let cuisineChips = CityListFilter.chips(for: many).filter { if case .cuisine = $0.kind { return true } else { return false } }
        XCTAssertEqual(cuisineChips.count, CityListFilter.maxCuisineChips)
    }

    // MARK: - Apply

    func testApply_AllKeepsEverything() {
        XCTAssertEqual(CityListFilter.apply(.all, to: sample).count, 7)
    }

    func testApply_TypeAndCuisine() {
        XCTAssertEqual(CityListFilter.apply(.type(.restaurants), to: sample).map(\.id), ["r1", "r2", "r3", "r4"])
        XCTAssertEqual(CityListFilter.apply(.cuisine("Japanese"), to: sample).map(\.id), ["r1", "r2"])
        XCTAssertEqual(CityListFilter.apply(.type(.stays), to: sample).count, 0)
    }

    // MARK: - Sorting

    func testSorted_NearestFirstWithUnknownLast() {
        let places = [place("far", .bars, distance: 900), place("none", .bars), place("near", .bars, distance: 100)]
        XCTAssertEqual(CityListFilter.sorted(places, byDistance: true).map(\.id), ["near", "far", "none"])
    }

    func testSorted_FallsBackToNewestWithoutDistance() {
        let old = Date(timeIntervalSince1970: 1_000), new = Date(timeIntervalSince1970: 2_000)
        let places = [place("old", .bars, addedAt: old), place("new", .bars, addedAt: new), place("undated", .bars)]
        XCTAssertEqual(CityListFilter.sorted(places, byDistance: true).map(\.id), ["new", "old", "undated"])
        XCTAssertEqual(CityListFilter.sorted(places, byDistance: false).map(\.id), ["new", "old", "undated"])
    }

    func testSorted_RecentOrderingIgnoresDistance() {
        let new = Date(timeIntervalSince1970: 2_000)
        let places = [place("near", .bars, distance: 1), place("new", .bars, distance: 500, addedAt: new)]
        XCTAssertEqual(CityListFilter.sorted(places, byDistance: false).map(\.id), ["new", "near"])
    }
}
