//
//  ListTypeFilterTests.swift
//  locTests
//
//  Tests for the tag chips inside a list: category/name mapping, chip ordering and thresholds, and filtering.
//

import XCTest
@testable import loc

final class ListTypeFilterTests: XCTestCase {

    // MARK: - Helpers

    private func place(_ id: String, _ name: String, type: String?) -> LightweightPlace {
        LightweightPlace(place_id: id, name: name, latest_review_photo: nil, place_type: type)
    }

    private func tags(_ name: String, _ type: String?) -> [String] {
        ListTypeFilter.tags(of: place("x", name, type: type))
    }

    /// `count` places with the same category, ids prefixed so several groups can be combined.
    private func group(_ prefix: String, _ type: String, count: Int) -> [LightweightPlace] {
        (0..<count).map { place("\(prefix)\($0)", "\(prefix) \($0)", type: type) }
    }

    private func titles(_ places: [LightweightPlace]) -> [String] {
        ListTypeFilter.chips(for: places).map(\.title)
    }

    // MARK: - Mapping

    func testTags_SushiRestaurantIsSushiAndJapanese() {
        XCTAssertEqual(tags("Nobu", "sushi_restaurant"), ["Sushi", "Japanese"])
    }

    func testTags_JapaneseRestaurantIsJapanese() {
        XCTAssertEqual(tags("Somewhere", "japanese_restaurant"), ["Japanese"])
        XCTAssertEqual(tags("Somewhere", "Japanese restaurant"), ["Japanese"])
    }

    func testTags_NameKeywordAddsTag() {
        XCTAssertEqual(tags("Joe's Pizza", "Restaurant"), ["Pizza"])
        XCTAssertEqual(tags("Ramen Danbo", "restaurant"), ["Ramen", "Japanese"])
        XCTAssertEqual(tags("Sushi Noz Omakase", nil), ["Sushi", "Japanese", "Omakase"])
    }

    func testTags_UnmappedCategoriesAreDropped() {
        XCTAssertTrue(tags("Mystery", "restaurant").isEmpty)
        XCTAssertTrue(tags("Mystery", "Fast food restaurant").isEmpty)
        XCTAssertTrue(tags("Mystery", nil).isEmpty)
    }

    func testTags_CoffeeBarsAndShops() {
        XCTAssertEqual(tags("Cafe Reggio", "Coffee shop"), ["Coffee"])
        XCTAssertEqual(tags("Dante", "Cocktail bar"), ["Cocktails"])
        XCTAssertEqual(tags("Terroir", "Wine bar"), ["Wine Bar"])
        XCTAssertEqual(tags("McSorley's", "Bar"), ["Bar"])
        XCTAssertEqual(tags("Strand", "Book store"), ["Shopping"])
        XCTAssertEqual(tags("Beacon's Closet", "Vintage clothing store"), ["Vintage", "Shopping"])
    }

    func testTags_NameWordsDoNotMisfire() {
        XCTAssertEqual(tags("Park Hyatt", "Hotel"), ["Hotel"])
        XCTAssertTrue(tags("Bar Pitti Notice", "restaurant").isEmpty)
    }

    func testTags_AccentsAndPunctuationNormalize() {
        XCTAssertEqual(tags("Café Select", "Café"), ["Coffee"])
        XCTAssertEqual(tags("Taco-Mex", "restaurant"), ["Mexican"])
    }

    // MARK: - Chip row

    func testChips_AllFirstThenMostCommonFirst() {
        let places = group("a", "Coffee shop", count: 5) + group("b", "Italian restaurant", count: 3)
            + group("c", "Pizza restaurant", count: 2) + group("d", "Cocktail bar", count: 4)
        XCTAssertEqual(titles(places), ["All", "Coffee", "Cocktails", "Italian", "Pizza"])
    }

    func testChips_TiesBreakAlphabetically() {
        let places = group("a", "Thai restaurant", count: 3) + group("b", "Korean restaurant", count: 3) + group("c", "Bar", count: 4)
        XCTAssertEqual(titles(places), ["All", "Bar", "Korean", "Thai"])
    }

    func testChips_LargeListNeedsTwoPlacesPerTag() {
        let places = group("a", "Coffee shop", count: 6) + group("b", "Thai restaurant", count: 3)
            + group("c", "Museum", count: 1)
        XCTAssertEqual(titles(places), ["All", "Coffee", "Thai"])
    }

    func testChips_SmallListAllowsSinglePlaceTags() {
        let places = [place("1", "A", type: "Thai restaurant"), place("2", "B", type: "Museum"), place("3", "C", type: "Park")]
        XCTAssertEqual(Set(titles(places)), ["All", "Thai", "Museum", "Park"])
    }

    func testChips_HiddenWhenFewerThanTwoTagsQualify() {
        XCTAssertTrue(ListTypeFilter.chips(for: []).isEmpty)
        XCTAssertTrue(ListTypeFilter.chips(for: [place("1", "A", type: "Thai restaurant")]).isEmpty)
        // One tag only (all Thai) in a big list.
        XCTAssertTrue(ListTypeFilter.chips(for: group("a", "Thai restaurant", count: 12)).isEmpty)
    }

    func testChips_CappedAtFifteenTags() {
        let categories = ["Thai", "Korean", "Indian", "French", "Greek", "Spanish", "Seafood", "Bakery", "Dessert", "Museum",
                          "Park", "Hotel", "Coffee shop", "Wine bar", "Brewery", "Mexican", "Italian", "Pizza"]
        let places = categories.flatMap { group($0, $0, count: 2) }
        XCTAssertEqual(ListTypeFilter.chips(for: places).count, 1 + ListTypeFilter.maxTagChips)
    }

    func testChips_MultiTagPlaceCountsTowardEachTag() {
        let places = group("a", "Sushi restaurant", count: 2) + group("b", "Japanese restaurant", count: 1)
            + group("c", "Coffee shop", count: 8)
        // Japanese: 3 (2 implied by sushi + 1), Sushi: 2, Coffee: 8.
        XCTAssertEqual(titles(places), ["All", "Coffee", "Japanese", "Sushi"])
    }

    // MARK: - Filtering

    func testApply_NilKeepsEverything() {
        let places = group("a", "Coffee shop", count: 3)
        XCTAssertEqual(ListTypeFilter.apply(nil, to: places).count, 3)
    }

    func testApply_MultiTagPlaceMatchesEitherTag() {
        let places = [place("1", "Nobu", type: "sushi_restaurant"), place("2", "Tokyo Diner", type: "japanese_restaurant"),
                      place("3", "Blue Bottle", type: "Coffee shop")]
        XCTAssertEqual(ListTypeFilter.apply("Sushi", to: places).map(\.place_id), ["1"])
        XCTAssertEqual(ListTypeFilter.apply("Japanese", to: places).map(\.place_id), ["1", "2"])
        XCTAssertTrue(ListTypeFilter.apply("Hotel", to: places).isEmpty)
    }

    // MARK: - View model

    private var mixed: [LightweightPlace] {
        [place("1", "Nobu", type: "sushi_restaurant"), place("2", "Dante", type: "Cocktail bar"),
         place("3", "Cafe Reggio", type: "Coffee shop"), place("4", "Strand", type: "Book store")]
    }

    @MainActor
    func testViewModel_TappingSelectedChipReturnsToAll() {
        let vm = ListTypeFilterViewModel()
        let coffee = ListTypeChip(tag: "Coffee", title: "Coffee")
        vm.select(coffee)
        XCTAssertTrue(vm.isSelected(coffee))
        XCTAssertEqual(vm.visiblePlaces(from: mixed).map(\.place_id), ["3"])
        vm.select(coffee)
        XCTAssertEqual(vm.visiblePlaces(from: mixed).count, 4)
    }

    @MainActor
    func testViewModel_SelectionForVanishedTagShowsEverything() {
        let vm = ListTypeFilterViewModel()
        vm.select(ListTypeChip(tag: "Cocktails", title: "Cocktails"))
        let withoutBar = mixed.filter { $0.place_id != "2" }
        XCTAssertEqual(vm.visiblePlaces(from: withoutBar).count, 3)
    }

    @MainActor
    func testViewModel_ChipsRefreshWhenPlacesChange() {
        let vm = ListTypeFilterViewModel()
        XCTAssertFalse(vm.chips(for: mixed).isEmpty)
        XCTAssertTrue(vm.chips(for: [mixed[2]]).isEmpty)
    }
}
