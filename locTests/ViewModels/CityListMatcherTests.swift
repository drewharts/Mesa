//
//  CityListMatcherTests.swift
//  locTests
//
//  Tests for the rules that pick (or decline to pick) one of the user's lists as a place's city list.
//

import XCTest
@testable import loc

final class CityListMatcherTests: XCTestCase {

    // MARK: - Helpers

    private func list(_ id: String, _ name: String, count: Int = 0, shared: Bool = false, tier: String? = nil) -> LightweightPlaceList {
        LightweightPlaceList(
            list_id: id, name: name, is_public: true, image: nil, created_at: nil, updated_at: nil,
            distance_meters: nil, place_count: count, city: nil, price_tier: tier, is_shared: shared
        )
    }

    private func matchId(_ city: String, _ lists: [LightweightPlaceList]) -> String? {
        CityListMatcher.match(cityName: city, in: lists)?.list_id
    }

    // MARK: - City name

    func testCityName_BoroughAddressIsNewYorkCity() {
        XCTAssertEqual(CityListMatcher.cityName(storedCity: nil, address: "188 Avenue B, New York, NY 10009"), "New York City")
        XCTAssertEqual(CityListMatcher.cityName(storedCity: "Brooklyn", address: "1 Main St, Brooklyn, NY 11201"), "New York City")
    }

    func testCityName_UnknownIsNil() {
        XCTAssertNil(CityListMatcher.cityName(storedCity: nil, address: nil))
        XCTAssertNil(CityListMatcher.cityName(storedCity: "", address: ""))
    }

    // MARK: - Matching

    func testMatch_IsCaseInsensitive() {
        XCTAssertEqual(matchId("Tokyo", [list("a", "tokyo")]), "a")
        XCTAssertEqual(matchId("New York City", [list("a", "NEW YORK CITY")]), "a")
    }

    func testMatch_IgnoresAccentsAndPunctuation() {
        XCTAssertEqual(matchId("Montréal", [list("a", "Montreal")]), "a")
    }

    func testMatch_NewYorkAliases() {
        for name in ["NYC", "New York", "nyc", "Manhattan", "Brooklyn", "Queens", "The Bronx"] {
            XCTAssertEqual(matchId("New York City", [list("a", name)]), "a", name)
        }
    }

    func testMatch_OtherNicknames() {
        XCTAssertEqual(matchId("San Francisco", [list("a", "SF")]), "a")
        XCTAssertEqual(matchId("Los Angeles", [list("a", "LA")]), "a")
        XCTAssertEqual(matchId("Philadelphia", [list("a", "Philly")]), "a")
    }

    func testMatch_ExactNameBeatsAlias() {
        let lists = [list("nyc", "NYC", count: 50), list("exact", "New York City", count: 2)]
        XCTAssertEqual(matchId("New York City", lists), "exact")
    }

    func testMatch_BiggestListWinsAmongAliases() {
        let lists = [list("a", "NYC", count: 3), list("b", "Brooklyn", count: 9)]
        XCTAssertEqual(matchId("New York City", lists), "b")
    }

    func testMatch_CityPlusTypeOrTripNamesDoNotMatch() {
        let lists = [list("a", "NYC Restaurants"), list("b", "Paris trip w/ Grace"), list("c", "Tokyo coffee")]
        XCTAssertNil(matchId("New York City", lists))
        XCTAssertNil(matchId("Paris", lists))
        XCTAssertNil(matchId("Tokyo", lists))
    }

    func testMatch_SkipsSharedAndPaidLists() {
        let lists = [list("shared", "Paris", shared: true), list("paid", "Paris", tier: "tier_1")]
        XCTAssertNil(matchId("Paris", lists))
    }

    func testMatch_BoroughNameDoesNotAliasOtherCities() {
        XCTAssertNil(matchId("Jamaica", [list("a", "New York City")]))
        XCTAssertEqual(matchId("Brooklyn", [list("a", "Brooklyn")]), "a")
    }

    func testMatch_NoListsReturnsNil() {
        XCTAssertNil(matchId("Paris", []))
    }

    func testMatch_FallbackListIsMatchedByName() {
        XCTAssertEqual(matchId(CityListMatcher.fallbackListName, [list("a", "saved")]), "a")
    }

    // MARK: - Summary text

    func testSummary_SinglePlaceMessage() {
        let summary = CitySaveSummary(listNames: ["New York City"], added: 1)
        XCTAssertEqual(summary.message, "Added to New York City")
    }

    func testSummary_ManyPlacesOneOrManyLists() {
        XCTAssertEqual(CitySaveSummary(listNames: ["Tokyo"], added: 3, alreadyThere: 1).message, "Added 4 places to Tokyo")
        XCTAssertEqual(CitySaveSummary(listNames: ["Tokyo", "Paris"], added: 2).message, "Added 2 places to 2 lists")
    }

    func testSummary_NothingSavedHasNoMessageAndFailuresAreNoted() {
        XCTAssertNil(CitySaveSummary(failed: 2).message)
        XCTAssertEqual(CitySaveSummary(listNames: ["Paris"], added: 2, failed: 1).message, "Added 2 places to Paris (1 failed)")
    }
}
