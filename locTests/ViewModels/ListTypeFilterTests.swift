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

    /// A place with a full raw categories array (and optionally a user-corrected category).
    private func place(_ id: String, _ name: String, categories: [String], corrected: String? = nil) -> LightweightPlace {
        LightweightPlace(place_id: id, name: name, latest_review_photo: nil, categories: categories, user_corrected_category: corrected)
    }

    private func tags(_ name: String, categories: [String], corrected: String? = nil) -> [String] {
        ListTypeFilter.tags(of: place("x", name, categories: categories, corrected: corrected))
    }

    /// `count` places sharing one categories array.
    private func group(_ prefix: String, categories: [String], count: Int) -> [LightweightPlace] {
        (0..<count).map { place("\(prefix)\($0)", "\(prefix) \($0)", categories: categories) }
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


    // MARK: - Full categories array

    func testTags_GenericFirstCategoriesAreIgnored() {
        XCTAssertEqual(tags("Somewhere", categories: ["establishment", "food", "point_of_interest", "restaurant"]), [])
        XCTAssertEqual(tags("Somewhere", categories: ["establishment", "food", "point_of_interest", "sushi_restaurant"]), ["Sushi", "Japanese"])
        XCTAssertEqual(tags("Somewhere", categories: ["food", "store", "meal_takeaway", "meal_delivery", "lounge", "event venue"]), [])
    }

    func testTags_BothCategoryFormatsAndCases() {
        XCTAssertEqual(tags("A", categories: ["Italian restaurant"]), ["Italian"])
        XCTAssertEqual(tags("A", categories: ["italian_restaurant"]), ["Italian"])
        XCTAssertEqual(tags("A", categories: ["Pizza restaurant"]), ["Pizza"])
        XCTAssertEqual(tags("A", categories: ["Mexican restaurant"]), ["Mexican"])
        XCTAssertEqual(tags("A", categories: ["cafe", "food"]), ["Coffee"])
        XCTAssertEqual(tags("A", categories: ["Coffee shop"]), ["Coffee"])
        XCTAssertEqual(tags("A", categories: ["bakery", "food"]), ["Bakery"])
    }

    func testTags_BarWithWineBarGetsBoth() {
        XCTAssertEqual(tags("A", categories: ["Bar", "Wine bar"]), ["Wine Bar", "Bar"])
        XCTAssertEqual(tags("A", categories: ["Restaurant", "Wine bar"]), ["Wine Bar"])
        XCTAssertEqual(tags("A", categories: ["bar", "establishment"]), ["Bar"])
        XCTAssertEqual(tags("A", categories: ["Pub"]), ["Bar"])
        XCTAssertEqual(tags("A", categories: ["Cocktail bar"]), ["Cocktails"])
    }

    func testTags_KoreanBarbecueIsKoreanBBQAndKorean() {
        XCTAssertEqual(tags("A", categories: ["Korean barbecue restaurant"]), ["Korean BBQ", "Korean"])
        XCTAssertEqual(tags("A", categories: ["korean_restaurant"]), ["Korean"])
        XCTAssertEqual(tags("A", categories: ["barbecue_restaurant"]), ["BBQ"])
    }

    func testTags_UsefulCategoryIsNotFirst() {
        XCTAssertEqual(tags("A", categories: ["Chinese restaurant", "Ramen restaurant", "Noodle shop"]), ["Ramen", "Japanese", "Chinese"])
    }

    func testTags_UserCorrectedCategoryWins() {
        XCTAssertEqual(tags("A", categories: ["Italian restaurant"], corrected: "Mexican restaurant"), ["Mexican"])
        // A correction that maps to nothing does not erase the original categories.
        XCTAssertEqual(tags("A", categories: ["Italian restaurant"], corrected: "restaurant"), ["Italian"])
    }

    func testTags_NameKeywordsFallBackWhenCategoriesAreGeneric() {
        let generic = ["establishment", "food", "point_of_interest", "restaurant"]
        XCTAssertEqual(tags("Joe's Pizza", categories: generic), ["Pizza"])
        XCTAssertEqual(tags("Blue Bottle Coffee", categories: generic), ["Coffee"])
        XCTAssertEqual(tags("Levain Bakery", categories: generic), ["Bakery"])
        XCTAssertEqual(tags("Terroir Wine", categories: generic), ["Wine Bar"])
    }

    func testTags_MissingCategoriesFallBackToPlaceType() {
        XCTAssertEqual(tags("A", "Italian restaurant"), ["Italian"])
    }

    func testChips_RealisticNewYorkList() {
        let generic = ["establishment", "food", "point_of_interest", "restaurant"]
        let places = group("gen", categories: generic, count: 54)
            + group("bar", categories: ["bar", "establishment"], count: 19)
            + group("sushi", categories: ["Sushi restaurant"], count: 16)
            + group("jp", categories: ["Japanese restaurant"], count: 13)
            + group("Bar", categories: ["Bar", "Wine bar"], count: 10)
            + group("rest", categories: ["Restaurant", "Wine bar"], count: 10)
            + group("it", categories: ["Italian restaurant"], count: 9)
            + group("cs", categories: ["Coffee shop"], count: 8)
            + group("mx", categories: ["Mexican restaurant"], count: 7)
            + group("pz", categories: ["Pizza restaurant"], count: 6)
            + group("kr", categories: ["Korean restaurant"], count: 5)
            + group("kb", categories: ["Korean barbecue restaurant"], count: 4)
            + group("cf", categories: ["cafe", "food", "establishment"], count: 5)
            + group("bk", categories: ["bakery", "food"], count: 4)
        let chips = titles(places)
        XCTAssertEqual(chips.first, "All")
        for expected in ["Sushi", "Japanese", "Bar", "Wine Bar", "Italian", "Coffee", "Mexican", "Pizza", "Korean"] {
            XCTAssertTrue(chips.contains(expected), "missing chip \(expected) in \(chips)")
        }
        XCTAssertLessThanOrEqual(chips.count, 1 + ListTypeFilter.maxTagChips)
        // Japanese = sushi (implied) 16 + 13; Coffee = 8 + 5, so Japanese outranks Coffee.
        XCTAssertLessThan(chips.firstIndex(of: "Japanese")!, chips.firstIndex(of: "Coffee")!)
    }

    func testDecode_MissingOrNullCategoriesDecode() throws {
        let json = #"[{"place_id":"1","name":"A"},{"place_id":"2","name":"B","categories":null,"user_corrected_category":null},{"place_id":"3","name":"C","categories":["bar","Wine bar"],"user_corrected_category":"Wine bar"}]"#
        let places = try JSONDecoder().decode([LightweightPlace].self, from: Data(json.utf8))
        XCTAssertNil(places[0].categories)
        XCTAssertNil(places[1].categories)
        XCTAssertEqual(places[2].categories, ["bar", "Wine bar"])
        XCTAssertEqual(places[2].user_corrected_category, "Wine bar")
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

    // MARK: - Display (memoized tiles)

    func testUniquePlaces_DropsDuplicateIdsIgnoringCase() {
        let places = [place("ABC", "A", type: nil), place("abc", "A again", type: nil), place("def", "B", type: nil)]
        XCTAssertEqual(ListTypeFilter.uniquePlaces(places).map(\.name), ["A", "B"])
    }

    @MainActor
    func testDisplay_UnfilteredKeepsAllUniqueTilesAndNoChips() {
        let vm = ListTypeFilterViewModel()
        let display = vm.display(for: mixed + [mixed[0]], filtersByType: false)
        XCTAssertEqual(display.tiles.count, mixed.count)
        XCTAssertTrue(display.chips.isEmpty)
    }

    @MainActor
    func testDisplay_AppliesSelectionAndRefreshesAfterChange() {
        let vm = ListTypeFilterViewModel()
        XCTAssertEqual(vm.display(for: mixed, filtersByType: true).tiles.count, mixed.count)
        vm.select(ListTypeChip(tag: "Cocktails", title: "Cocktails"))
        XCTAssertEqual(vm.display(for: mixed, filtersByType: true).tiles.count, vm.visiblePlaces(from: mixed).count)
    }

    @MainActor
    func testDisplay_ReflectsChangedPlaceFieldsWithSameIds() {
        let vm = ListTypeFilterViewModel()
        _ = vm.display(for: mixed, filtersByType: true)
        var renamed = mixed
        renamed[0] = place(mixed[0].place_id, "Renamed", type: mixed[0].place_type)
        XCTAssertEqual(vm.display(for: renamed, filtersByType: true).tiles.first?.name, "Renamed")
    }

    @MainActor
    func testDisplay_LoadMoreTriggersAreTheLastThreeTiles() {
        let vm = ListTypeFilterViewModel()
        let places = group("p", "restaurant", count: 10)
        let ids = vm.display(for: places, filtersByType: false).loadMoreTriggerIds
        XCTAssertEqual(ids, ["p7", "p8", "p9"])
    }
}

// MARK: - Whole-list chips and filter loading

@MainActor
final class ListTypeFilterWholeListTests: XCTestCase {

    private func place(_ id: String, _ name: String, categories: [String] = [], corrected: String? = nil) -> LightweightPlace {
        LightweightPlace(place_id: id, name: name, latest_review_photo: nil, categories: categories, user_corrected_category: corrected)
    }

    /// 40 tag-source rows: 23 sushi, 13 wine bars, 4 Korean.
    private var source: [LightweightPlace] {
        (0..<23).map { place("s\($0)", "Spot \($0)", categories: ["sushi_restaurant"]) }
            + (0..<13).map { place("w\($0)", "Cellar \($0)", categories: ["wine_bar"]) }
            + (0..<4).map { place("k\($0)", "Hall \($0)", categories: ["korean_restaurant"]) }
    }

    private func makeVM(source: [LightweightPlace]?) -> ListTypeFilterViewModel {
        ListTypeFilterViewModel(tagSourceLoader: { _ in source }, cache: ListTagSourceCache())
    }

    func testChips_ComeFromWholeSourceNotLoadedPages() async {
        let vm = makeVM(source: source)
        let firstPage = Array(source.prefix(6))
        await vm.refreshTagSource(listId: "L", loaded: firstPage)
        let titles = vm.display(for: firstPage, filtersByType: true).chips.map(\.title)
        XCTAssertEqual(titles.first, "All")
        XCTAssertTrue(titles.contains("Sushi"))
        XCTAssertTrue(titles.contains("Wine Bar"))
        XCTAssertTrue(titles.contains("Korean"))
    }

    func testUnloadedMatchIds_ListsMatchesBeyondLoadedPages() async {
        let vm = makeVM(source: source)
        let loaded = Array(source.prefix(6))
        await vm.refreshTagSource(listId: "L", loaded: loaded)
        vm.select(ListTypeChip(tag: "Wine Bar", title: "Wine Bar"))
        XCTAssertEqual(vm.unloadedMatchIds(loaded: loaded).count, 13)
    }

    func testLoadMatches_CallsLoadAllWhenMatchesMissingAndClearsSpinner() async {
        let vm = makeVM(source: source)
        var loaded = Array(source.prefix(6))
        await vm.refreshTagSource(listId: "L", loaded: loaded)
        vm.select(ListTypeChip(tag: "Wine Bar", title: "Wine Bar"))
        var calls = 0
        await vm.loadMatchesIfNeeded(loaded: { loaded }, loadAll: { calls += 1; loaded = self.source })
        XCTAssertEqual(calls, 1)
        XCTAssertFalse(vm.isLoadingMatches)
        XCTAssertEqual(vm.visiblePlaces(from: loaded).count, 13)
    }

    func testLoadMatches_SkipsLoadAllWhenAllMatchesLoadedOrAllSelected() async {
        let vm = makeVM(source: source)
        let all = source
        await vm.refreshTagSource(listId: "L", loaded: all)
        var calls = 0
        await vm.loadMatchesIfNeeded(loaded: { all }, loadAll: { calls += 1 })
        vm.select(ListTypeChip(tag: "Korean", title: "Korean"))
        await vm.loadMatchesIfNeeded(loaded: { all }, loadAll: { calls += 1 })
        XCTAssertEqual(calls, 0)
    }

    func testRefresh_FailureKeepsLoadedBasedChips() async {
        let vm = makeVM(source: nil)
        await vm.refreshTagSource(listId: "L", loaded: source)
        XCTAssertNil(vm.fullIndex)
        XCTAssertFalse(vm.display(for: source, filtersByType: true).chips.isEmpty)
    }

    func testRefresh_UsesCacheThenSkipsRefetchUntilPlaceAdded() async {
        var fetches = 0
        let cache = ListTagSourceCache()
        let src = source
        let vm = ListTypeFilterViewModel(tagSourceLoader: { _ in fetches += 1; return src }, cache: cache)
        await vm.refreshTagSource(listId: "L", loaded: src)
        await vm.refreshTagSource(listId: "L", loaded: src)
        XCTAssertEqual(fetches, 1)
        await vm.refreshTagSource(listId: "L", loaded: src + [place("new", "Fresh Sushi")])
        XCTAssertEqual(fetches, 2)
        XCTAssertNotNil(cache.index(for: "l"))
    }

    func testNameRule_SushiPrefixWordMatchesButOtherWordsDoNot() {
        XCTAssertTrue(ListTypeFilter.tags(of: place("1", "SUSHIRO")).contains("Sushi"))
        XCTAssertTrue(ListTypeFilter.tags(of: place("2", "Sushiya Ginza")).contains("Sushi"))
        XCTAssertFalse(ListTypeFilter.tags(of: place("3", "Nonsushi Deli")).contains("Sushi"))
    }
}
