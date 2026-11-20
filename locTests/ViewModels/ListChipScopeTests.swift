//
//  ListChipScopeTests.swift
//  locTests
//
//  Tests that a selected tag chip scopes the header count and the map pins, and that every chip from
//  Drew's old category lists (Bar, Coffee, Grocery, Japanese, Korean, Lunch, Matcha, Mexican, Omakase,
//  Pizza, Sushi, Ramen, Wine Bar) has a rule.
//

import XCTest
import CoreLocation
@testable import loc

@MainActor
final class ListChipScopeTests: XCTestCase {

    // MARK: - Helpers

    private func place(_ id: String, _ name: String, categories: [String]) -> LightweightPlace {
        LightweightPlace(place_id: id, name: name, latest_review_photo: nil, categories: categories)
    }

    private func annotation(_ id: String) -> PlaceAnnotation {
        PlaceAnnotation(id: id, name: id, coordinate: CLLocationCoordinate2D(latitude: 1, longitude: 1), userIds: [], placeType: "bar")
    }

    private var places: [LightweightPlace] {
        [place("A1", "Joe's", categories: ["pizza_restaurant"]),
         place("B2", "Lucali", categories: ["Pizza restaurant"]),
         place("C3", "Dante", categories: ["bar"]),
         place("D4", "Attaboy", categories: ["bar"]),
         place("E5", "Blue Bottle", categories: ["coffee_shop"])]
    }

    private func makeViewModel() async -> ListTypeFilterViewModel {
        let source = places
        let vm = ListTypeFilterViewModel(tagSourceLoader: { _ in source }, cache: ListTagSourceCache())
        await vm.refreshTagSource(listId: "list", loaded: [])
        return vm
    }

    override func tearDown() {
        ListMapSheetViewModel.shared.endSession()
        super.tearDown()
    }

    // MARK: - Scope ids

    func testScopeIdsNilOnAll() async {
        let vm = await makeViewModel()
        XCTAssertNil(vm.display(for: places, filtersByType: true).scopeIds)
    }

    func testScopeIdsCoverWholeListEvenWhenOnlyPartLoaded() async {
        let vm = await makeViewModel()
        vm.select(ListTypeChip(tag: "Pizza", title: "Pizza"))
        let display = vm.display(for: [places[0]], filtersByType: true)
        XCTAssertEqual(display.scopeIds, ["a1", "b2"])
    }

    func testScopeIdsNilWhenTypeFilterOff() async {
        let vm = await makeViewModel()
        vm.select(ListTypeChip(tag: "Pizza", title: "Pizza"))
        XCTAssertNil(vm.display(for: places, filtersByType: false).scopeIds)
    }

    func testSelectingAllAgainClearsScope() async {
        let vm = await makeViewModel()
        let pizza = ListTypeChip(tag: "Pizza", title: "Pizza")
        vm.select(pizza)
        vm.select(pizza)
        XCTAssertNil(vm.display(for: places, filtersByType: true).scopeIds)
    }

    // MARK: - Header count

    func testHeaderCountShowsTotalOnAll() {
        ListMapSheetViewModel.shared.setChipScope(nil)
        XCTAssertEqual(ListMapSheetViewModel.shared.headerPlaceCount(total: 293), 293)
    }

    func testHeaderCountShowsChipCountThenRestoresTotal() {
        let sheet = ListMapSheetViewModel.shared
        sheet.setChipScope(Set((0..<23).map { "id\($0)" }))
        XCTAssertEqual(sheet.headerPlaceCount(total: 293), 23)
        sheet.setChipScope(nil)
        XCTAssertEqual(sheet.headerPlaceCount(total: 293), 293)
    }

    func testEndSessionClearsChipScope() {
        let sheet = ListMapSheetViewModel.shared
        sheet.setChipScope(["a"])
        sheet.endSession()
        XCTAssertNil(sheet.chipScopeIds)
    }

    // MARK: - Map pins

    func testPinFilterKeepsEverythingOnAll() {
        let pins = [annotation("A1"), annotation("B2")]
        XCTAssertEqual(ListMapPinFilter.apply(pins, allowedIds: nil).map(\.id), ["A1", "B2"])
    }

    func testPinFilterKeepsOnlyScopeCaseInsensitively() {
        let pins = [annotation("A1"), annotation("B2"), annotation("C3")]
        XCTAssertEqual(ListMapPinFilter.apply(pins, allowedIds: ["a1", "c3"]).map(\.id), ["A1", "C3"])
    }

    func testPinFilterDiffTouchesOnlyChangedPins() {
        let all = Set(["a1", "b2", "c3", "d4"])
        let diff = MapIdDiff(old: all, new: ["a1", "b2"])
        XCTAssertEqual(diff.removed, ["c3", "d4"])
        XCTAssertTrue(diff.added.isEmpty)
        XCTAssertEqual(diff.kept, ["a1", "b2"])
    }

    // MARK: - Skeletons and prefetch sizing

    func testNoSkeletonsWhenNothingIsLoading() async {
        let vm = await makeViewModel()
        XCTAssertEqual(vm.pendingSkeletonCount(loaded: places), 0)
    }

    func testSkeletonsOnlyForUnloadedMatchesAndCapped() async {
        let vm = await makeViewModel()
        vm.select(ListTypeChip(tag: "Pizza", title: "Pizza"))
        vm.beginLoadingMatchesIfNeeded(loaded: [places[2]])
        XCTAssertEqual(vm.pendingSkeletonCount(loaded: [places[2]]), 2)
    }

    func testGridTileSideRoundsDown() {
        XCTAssertEqual(ListTypeFilterViewModel.gridTileSide(screenWidth: 393), 174)
    }

    // MARK: - Old category list parity rules

    func testEveryOldCategoryListHasAChip() {
        let cases: [(String, String)] = [
            ("Bar", "Bar"), ("Coffee shop", "Coffee"), ("Grocery store", "Grocery"),
            ("Japanese restaurant", "Japanese"), ("Korean restaurant", "Korean"), ("Lunch restaurant", "Lunch"),
            ("Matcha", "Matcha"), ("Mexican restaurant", "Mexican"), ("Omakase restaurant", "Omakase"),
            ("Pizza restaurant", "Pizza"), ("Sushi restaurant", "Sushi"), ("Ramen restaurant", "Ramen"),
            ("Wine bar", "Wine Bar")
        ]
        for (category, tag) in cases {
            let tags = ListTypeFilter.tags(of: place("x", "Somewhere", categories: [category]))
            XCTAssertTrue(tags.contains(tag), "\(category) should earn the \(tag) chip, got \(tags)")
        }
    }

    func testWineShopStaysSeparateFromWineBar() {
        let tags = ListTypeFilter.tags(of: place("x", "Terroir", categories: ["Wine store"]))
        XCTAssertTrue(tags.contains("Wine Shop"))
        XCTAssertFalse(tags.contains("Wine Bar"))
    }
}
