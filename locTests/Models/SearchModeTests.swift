//
//  SearchModeTests.swift
//  locTests
//
//  Tests for SearchPlan: Places mode never hits user search, People mode never hits Google Places.
//

import XCTest
@testable import loc

final class SearchModeTests: XCTestCase {

    func testPlacesMode_SearchesPlacesAndKeywordsNotUsers() {
        let plan = SearchPlan.make(mode: .places, query: "pizza")
        XCTAssertTrue(plan.searchesPlaces)
        XCTAssertTrue(plan.searchesKeywords)
        XCTAssertFalse(plan.searchesUsers)
        XCTAssertFalse(plan.searchesAI)
    }

    func testPeopleMode_SearchesOnlyUsers() {
        let plan = SearchPlan.make(mode: .people, query: "drew hartsfield and friends")
        XCTAssertTrue(plan.searchesUsers)
        XCTAssertFalse(plan.searchesPlaces)
        XCTAssertFalse(plan.searchesKeywords)
        XCTAssertFalse(plan.searchesAI)
    }

    func testPlacesMode_LongQueryAlsoSearchesAI() {
        let plan = SearchPlan.make(mode: .places, query: "cozy wine bar with outdoor seating")
        XCTAssertTrue(plan.searchesAI)
    }

    func testShortQuery_SearchesNothing() {
        for mode in SearchMode.allCases {
            let plan = SearchPlan.make(mode: mode, query: "a")
            XCTAssertFalse(plan.searchesPlaces || plan.searchesUsers || plan.searchesKeywords || plan.searchesAI)
        }
    }

    func testDefaultModeIsPlacesAndOrderIsPlacesThenPeople() {
        XCTAssertEqual(SearchMode.allCases, [.places, .people])
        XCTAssertEqual(SearchMode.places.title, "Places")
        XCTAssertEqual(SearchMode.people.title, "People")
    }
}
