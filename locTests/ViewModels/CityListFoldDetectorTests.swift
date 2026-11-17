//
//  CityListFoldDetectorTests.swift
//  locTests
//
//  Tests for spotting "city + type" lists that fold into the per-city Saved library: name parsing,
//  city / type agreement with the list's places, and the guards that keep shared lists visible.
//

import XCTest
@testable import loc

final class CityListFoldDetectorTests: XCTestCase {

    // MARK: - Helpers

    private func nyc(_ id: String, _ name: String, _ categories: [String]) -> SavedPlaceInput {
        input(id, name, city: "New York", address: "10 Main St, New York, NY 10010, USA", categories: categories)
    }

    private func input(_ id: String, _ name: String, city: String, address: String? = nil,
                       categories: [String], google: String? = nil) -> SavedPlaceInput {
        SavedPlaceInput(
            id: id, name: name, address: address, storedCity: city, latitude: nil, longitude: nil,
            categories: categories, userCorrectedCategory: nil, googlePlaceId: google,
            isDinnerSpot: false, addedAt: nil, sources: [.list]
        )
    }

    private func list(_ id: String, _ name: String, places: [String]?, isPublic: Bool = false,
                      collaborative: Bool = false, paid: Bool = false) -> FoldCandidateList {
        FoldCandidateList(id: id, name: name, isPublic: isPublic, isCollaborative: collaborative,
                          isPaid: paid, placeIds: places.map { Set($0) })
    }

    private func decision(_ list: FoldCandidateList, _ inputs: [SavedPlaceInput]) -> FoldDecision? {
        let library = SavedLibraryBuilder.build(inputs, userLocation: nil)
        return CityListFoldDetector.detect([list], library: library)[list.id]
    }

    private let nycRestaurants = ["a", "b", "c"]
    private func nycRestaurantInputs() -> [SavedPlaceInput] {
        [nyc("a", "Semma", ["Indian restaurant"]), nyc("b", "Via Carota", ["Italian restaurant"]), nyc("c", "Joe's Pizza", ["Pizza restaurant"])]
    }

    // MARK: - Folds

    func testFold_CityAndType() {
        XCTAssertEqual(decision(list("l", "NYC Restaurants", places: nycRestaurants), nycRestaurantInputs()), .fold)
    }

    func testFold_CityNameVariants() {
        let inputs = nycRestaurantInputs()
        for name in ["New York restaurants", "restaurants in nyc", "My NYC places", "NYC", "New York City Food"] {
            XCTAssertEqual(decision(list("l", name, places: nycRestaurants), inputs), .fold, name)
        }
    }

    func testFold_TypeWordsForOtherTypes() {
        let tokyo = [input("t1", "Fuglen", city: "Tokyo", categories: ["Coffee shop"]), input("t2", "Onibus", city: "Tokyo", categories: ["Coffee shop"])]
        XCTAssertEqual(decision(list("l", "Tokyo coffee", places: ["t1", "t2"]), tokyo), .fold)
        let paris = [input("p1", "Le Syndicat", city: "Paris", categories: ["Cocktail bar"]), input("p2", "Candelaria", city: "Paris", categories: ["Cocktail bar"])]
        XCTAssertEqual(decision(list("l", "Paris bars", places: ["p1", "p2"]), paris), .fold)
    }

    func testFold_AreaOnlyName() {
        let brooklyn = [
            input("b1", "La Chacra", city: "New York City", address: "1928 Bath Ave, Brooklyn, NY 11214, USA", categories: ["restaurant"]),
            input("b2", "Hometown", city: "New York City", address: "454 Van Brunt St, Brooklyn, NY 11231, USA", categories: ["restaurant"])
        ]
        XCTAssertEqual(decision(list("l", "Brooklyn", places: ["b1", "b2"]), brooklyn), .fold)
    }

    func testFold_CuisineNameNeedsThatCuisine() {
        let inputs = nycRestaurantInputs()
        XCTAssertEqual(decision(list("l", "Italian NYC", places: ["b"]), inputs), .fold)
        XCTAssertEqual(decision(list("l", "Italian restaurants NYC", places: nycRestaurants), inputs), .keep(.nameDoesNotMatchPlaces))
    }

    func testFold_PlaceMergedIntoAnotherRowStillCounts() {
        let inputs = [
            nyc("a", "Semma", ["Indian restaurant"]),
            input("a2", "Semma", city: "New York", address: "10 Main St, New York, NY 10010, USA", categories: ["Indian restaurant"])
        ].map { var p = $0; p.googlePlaceId = "g1"; return p }
        XCTAssertEqual(decision(list("l", "NYC Restaurants", places: ["a2"]), inputs), .fold)
    }

    // MARK: - Keeps

    func testKeep_SharedPublicAndPaidListsStayVisible() {
        let inputs = nycRestaurantInputs()
        XCTAssertEqual(decision(list("l", "NYC Restaurants", places: nycRestaurants, isPublic: true), inputs), .keep(.isPublic))
        XCTAssertEqual(decision(list("l", "NYC Restaurants", places: nycRestaurants, collaborative: true), inputs), .keep(.collaborative))
        XCTAssertEqual(decision(list("l", "NYC Restaurants", places: nycRestaurants, paid: true), inputs), .keep(.paid))
    }

    func testKeep_NamesThatAreNotCityOrType() {
        let inputs = nycRestaurantInputs()
        for name in ["Date night", "Favorites", "Mom's picks", "NYC date night", "Trip", ""] {
            XCTAssertEqual(decision(list("l", name, places: nycRestaurants), inputs), .keep(.nameNotCityOrType), name)
        }
    }

    func testKeep_MembershipProblems() {
        let inputs = nycRestaurantInputs()
        XCTAssertEqual(decision(list("l", "NYC Restaurants", places: nil), inputs), .keep(.membershipUnknown))
        XCTAssertEqual(decision(list("l", "NYC Restaurants", places: []), inputs), .keep(.empty))
        XCTAssertEqual(decision(list("l", "NYC Restaurants", places: ["a", "missing"]), inputs), .keep(.placesNotInLibrary))
    }

    func testKeep_NameDisagreesWithPlaces() {
        let inputs = nycRestaurantInputs()
        // A city none of its places are in is not a city this list can fold into.
        XCTAssertEqual(decision(list("l", "Paris restaurants", places: nycRestaurants), inputs), .keep(.nameNotCityOrType))
        XCTAssertEqual(decision(list("l", "NYC Bars", places: nycRestaurants), inputs), .keep(.nameDoesNotMatchPlaces))
    }

    func testKeep_MostlyOtherCityStaysVisible() {
        let inputs = [nyc("a", "Semma", ["restaurant"]),
                      input("p1", "Septime", city: "Paris", categories: ["restaurant"]),
                      input("p2", "Frenchie", city: "Paris", categories: ["restaurant"])]
        XCTAssertEqual(decision(list("l", "NYC Restaurants", places: ["a", "p1", "p2"]), inputs), .keep(.nameDoesNotMatchPlaces))
    }

    // MARK: - Name parsing

    func testParseName_ReadsCitiesTypesAndCuisines() {
        let places = SavedLibraryBuilder.build(nycRestaurantInputs(), userLocation: nil).cities.flatMap(\.places)
        let parsed = CityListFoldDetector.parseName("NYC Italian Restaurants", places: places)
        XCTAssertEqual(parsed?.cityPhrases, ["nyc"])
        XCTAssertEqual(parsed?.types, [.restaurants])
        XCTAssertEqual(parsed?.cuisines, ["italian"])
        XCTAssertNil(CityListFoldDetector.parseName("Best NYC restaurants", places: places))
        XCTAssertNil(CityListFoldDetector.parseName("My places", places: places))
    }

    func testFoldedIds_KeepsInputOrder() {
        let library = SavedLibraryBuilder.build(nycRestaurantInputs(), userLocation: nil)
        let lists = [list("1", "NYC Restaurants", places: ["a"]), list("2", "Date night", places: ["b"]), list("3", "NYC food", places: ["c"])]
        XCTAssertEqual(CityListFoldDetector.foldedIds(lists, library: library), ["1", "3"])
    }
}
