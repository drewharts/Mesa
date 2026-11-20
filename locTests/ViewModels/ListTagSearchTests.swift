//
//  ListTagSearchTests.swift
//  locTests
//
//  Tests the pure category-search engine: tag matching and ranking (names, synonyms, group names, diacritics),
//  place matching over names, categories and tags, and the view model's live narrowing of chips and places.
//

import XCTest
@testable import loc

@MainActor
final class ListTagSearchTests: XCTestCase {

    // MARK: - Helpers

    private func place(_ id: String, _ name: String, categories: [String]) -> LightweightPlace {
        LightweightPlace(place_id: id, name: name, latest_review_photo: nil, categories: categories)
    }

    private let allTags = ["Coffee", "Bar", "Cocktails", "Wine Bar", "Wine Shop", "Vintage Clothing", "Sushi", "Japanese", "Records", "Park"]

    private func ranked(_ query: String) -> [String] {
        ListTagSearch.rankedTags(matching: query, in: allTags)
    }

    private var places: [LightweightPlace] {
        [place("A1", "Joe's Pizza", categories: ["pizza_restaurant"]),
         place("B2", "Lucali", categories: ["pizza_restaurant"]),
         place("C3", "Dante", categories: ["bar"]),
         place("D4", "Attaboy", categories: ["bar"]),
         place("E5", "Blue Bottle", categories: ["coffee_shop"]),
         place("F6", "Stella Vintage", categories: ["Vintage clothing store"]),
         place("G7", "Rag Shop", categories: ["thrift_store"]),
         place("H8", "Café Réunion", categories: ["cafe"])]
    }

    private func makeViewModel() async -> ListTypeFilterViewModel {
        let source = places
        let vm = ListTypeFilterViewModel(tagSourceLoader: { _ in source }, cache: ListTagSourceCache())
        await vm.refreshTagSource(listId: "list", loaded: [])
        return vm
    }

    // MARK: - Tag matching

    func testBlankQueryMatchesNothing() {
        XCTAssertEqual(ranked(""), [])
        XCTAssertEqual(ranked("  !! "), [])
    }

    func testVinMatchesVintageClothingAndWineTags() {
        let result = ranked("vin")
        XCTAssertEqual(result.first, "Vintage Clothing")
        XCTAssertTrue(result.contains("Wine Bar"))
        XCTAssertTrue(result.contains("Wine Shop"))
        XCTAssertFalse(result.contains("Sushi"))
    }

    func testThriftMatchesVintageClothingBySynonym() {
        XCTAssertEqual(ranked("thrift"), ["Vintage Clothing"])
        XCTAssertEqual(ranked("secondhand"), ["Vintage Clothing"])
    }

    func testSushPrefixMatchesSushi() {
        XCTAssertEqual(ranked("sush"), ["Sushi"])
    }

    func testCoffeeAndCafeMatchCoffee() {
        XCTAssertEqual(ranked("coffee"), ["Coffee"])
        XCTAssertEqual(ranked("cafe"), ["Coffee"])
    }

    func testDrinksMatchesDrinkGroupTags() {
        let result = Set(ranked("drinks"))
        XCTAssertTrue(result.isSuperset(of: ["Bar", "Cocktails", "Wine Bar"]))
        XCTAssertFalse(result.contains("Sushi"))
    }

    func testMatchingIsCaseAndDiacriticInsensitive() {
        XCTAssertEqual(ranked("SUSHI"), ["Sushi"])
        XCTAssertEqual(ranked("cafÉ"), ["Coffee"])
    }

    func testWordPrefixRanksBeforeSubstring() {
        let tags = ["Brewery", "Bar", "Wine Bar", "Barbecue"]
        let result = ListTagSearch.rankedTags(matching: "bar", in: tags)
        XCTAssertEqual(result, ["Bar", "Barbecue", "Wine Bar"])
        // Substring only: "rew" is inside "Brewery" but starts no word.
        XCTAssertEqual(ListTagSearch.rankedTags(matching: "rew", in: tags), ["Brewery"])
    }

    func testNameMatchRanksBeforeSynonymAndGroupMatches() {
        // "bar": Bar is exact and Wine Bar a word prefix; Cocktails does not match.
        let result = ranked("bar")
        XCTAssertEqual(Array(result.prefix(2)), ["Bar", "Wine Bar"])
        XCTAssertFalse(result.contains("Cocktails"))
    }

    func testMultiWordQueryMatchesEachWordAsPrefix() {
        XCTAssertEqual(ranked("wine b"), ["Wine Bar"])
        XCTAssertEqual(ranked("clothing vin"), ["Vintage Clothing"])
    }

    func testEqualRanksKeepGivenOrder() {
        XCTAssertEqual(ListTagSearch.rankedTags(matching: "wine", in: ["Wine Shop", "Wine Bar"]), ["Wine Shop", "Wine Bar"])
    }

    func testTagWithNoSynonymEntryStillMatchesByName() {
        XCTAssertEqual(ListTagSearch.rankedTags(matching: "zzz", in: ["Zzzebra"]), ["Zzzebra"])
    }

    // MARK: - Place matching

    func testSearchFindsPlacesByNameCategoryAndTag() {
        let index = ListTypeFilter.index(for: places)
        XCTAssertEqual(ListTagSearch.search("lucali", in: index)?.placeIds, ["b2"])
        XCTAssertEqual(ListTagSearch.search("thrift", in: index)?.placeIds, ["f6", "g7"])
        XCTAssertEqual(ListTagSearch.search("pizza", in: index)?.placeIds, ["a1", "b2"])
        XCTAssertEqual(ListTagSearch.search("reunion", in: index)?.placeIds, ["h8"])
    }

    func testSearchIncludesTagsCarriedByOnePlace() {
        // 13 places: Bar and Coffee qualify as chips, but the single vintage shop's tag does not.
        let list = (1...6).map { place("bar\($0)", "Bar \($0)", categories: ["bar"]) }
            + (1...6).map { place("cof\($0)", "Roast \($0)", categories: ["coffee_shop"]) }
            + [place("vin1", "Stella Vintage", categories: ["Vintage clothing store"])]
        let index = ListTypeFilter.index(for: list)
        XCTAssertFalse(index.chips.contains { $0.tag == "Vintage Clothing" })
        XCTAssertTrue(index.allTags.contains("Vintage Clothing"))
        XCTAssertEqual(ListTagSearch.search("vintage", in: index)?.tags.first, "Vintage Clothing")
    }

    func testBlankSearchIsNil() {
        XCTAssertNil(ListTagSearch.search("   ", in: ListTypeFilter.index(for: places)))
    }

    // MARK: - View model

    func testQueryNarrowsChipsAndTiles() async {
        let vm = await makeViewModel()
        vm.beginSearch()
        vm.setSearchQuery("thrift")
        let display = vm.display(for: places, filtersByType: true)
        XCTAssertEqual(display.chips.map(\.tag), ["Vintage Clothing"])
        XCTAssertEqual(Set(display.tiles.map(\.place_id)), ["F6", "G7"])
        XCTAssertEqual(display.scopeIds, ["f6", "g7"])
        XCTAssertTrue(display.showsFilterRow)
    }

    func testClearingQueryRestoresEverything() async {
        let vm = await makeViewModel()
        vm.beginSearch()
        vm.setSearchQuery("thrift")
        vm.clearOrCloseSearch()
        XCTAssertTrue(vm.isSearching)
        let display = vm.display(for: places, filtersByType: true)
        XCTAssertEqual(display.tiles.count, places.count)
        XCTAssertNil(display.scopeIds)
        vm.clearOrCloseSearch()
        XCTAssertFalse(vm.isSearching)
    }

    func testTappingMatchedChipSelectsItAndCollapsesSearch() async {
        let vm = await makeViewModel()
        vm.beginSearch()
        vm.setSearchQuery("vint")
        vm.handleChipTap(ListTypeChip(tag: "Vintage Clothing", title: "Vintage Clothing"))
        XCTAssertFalse(vm.isSearching)
        XCTAssertEqual(vm.searchQuery, "")
        XCTAssertEqual(vm.selection, "Vintage Clothing")
        let display = vm.display(for: places, filtersByType: true)
        XCTAssertEqual(Set(display.tiles.map(\.place_id)), ["F6", "G7"])
        XCTAssertTrue(display.chips.contains { $0.tag == "Vintage Clothing" })
        XCTAssertTrue(vm.isSelected(ListTypeChip(tag: "Vintage Clothing", title: "Vintage Clothing")))
    }

    func testSearchOverridesSelectionUntilCleared() async {
        let vm = await makeViewModel()
        vm.select(ListTypeChip(tag: "Bar", title: "Bar"))
        vm.beginSearch()
        vm.setSearchQuery("lucali")
        XCTAssertEqual(vm.display(for: places, filtersByType: true).tiles.map(\.place_id), ["B2"])
        vm.endSearch()
        XCTAssertEqual(Set(vm.display(for: places, filtersByType: true).tiles.map(\.place_id)), ["C3", "D4"])
    }

    func testSearchMatchesUnloadedPlacesFromWholeListIndex() async {
        let vm = await makeViewModel()
        vm.setSearchQuery("lucali")
        let loaded = [places[2]]
        XCTAssertEqual(vm.unloadedMatchIds(loaded: loaded), ["b2"])
    }
}
