//
//  PlaceTypeEmojiTests.swift
//  locTests
//
//  Tests for PlaceTypeEmoji mapping from place type strings to emojis.
//  Covers normalization (underscore → space, case insensitivity) and
//  category-specific mappings.
//

import XCTest
@testable import loc

final class PlaceTypeEmojiTests: XCTestCase {

    // MARK: - Normalization

    func testUnderscoresNormalizedToSpaces() {
        // Raw Google type "ice_cream_shop" should match "ice cream"
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "ice_cream_shop"), "🍦")
    }

    func testCaseInsensitive() {
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "PIZZA"), "🍕")
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "Pizza Restaurant"), "🍕")
    }

    // MARK: - Food & Dining

    func testPizza() {
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "pizza"), "🍕")
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "pizza_restaurant"), "🍕")
    }

    func testItalian() {
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "italian_restaurant"), "🍝")
    }

    func testBurger() {
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "burger_restaurant"), "🍔")
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "hamburger"), "🍔")
    }

    func testSushi() {
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "sushi_bar"), "🍣")
    }

    func testRamen() {
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "ramen_restaurant"), "🍜")
    }

    func testTaco() {
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "taco_shop"), "🌮")
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "mexican_restaurant"), "🌮")
    }

    func testIndian() {
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "indian_restaurant"), "🍛")
    }

    func testMediterranean() {
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "greek_restaurant"), "🥙")
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "mediterranean"), "🥙")
    }

    func testSeafood() {
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "seafood_restaurant"), "🦞")
    }

    func testSteakhouse() {
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "steakhouse"), "🥩")
    }

    func testBBQ() {
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "barbecue_restaurant"), "🍖")
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "bbq"), "🍖")
    }

    // MARK: - Bakery & Sweets

    func testBakery() {
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "bakery"), "🧁")
    }

    func testIceCream() {
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "ice_cream_shop"), "🍦")
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "gelato"), "🍦")
    }

    func testDonut() {
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "donut_shop"), "🍩")
    }

    // MARK: - Drinks

    func testCoffee() {
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "coffee_shop"), "☕")
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "cafe"), "☕")
    }

    func testBubbleTea() {
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "bubble_tea"), "🧋")
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "boba"), "🧋")
    }

    func testBar() {
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "bar"), "🍺")
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "pub"), "🍺")
    }

    func testWine() {
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "wine_bar"), "🍷")
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "winery"), "🍷")
    }

    func testBrewery() {
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "brewery"), "🍺")
    }

    func testCocktail() {
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "cocktail_bar"), "🍸")
    }

    // MARK: - Shopping

    func testClothing() {
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "clothing_store"), "👕")
    }

    func testBookstore() {
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "bookstore"), "📚")
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "book_store"), "📚")
    }

    func testGrocery() {
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "grocery_store"), "🛒")
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "supermarket"), "🛒")
    }

    // MARK: - Parks & Nature

    func testPark() {
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "park"), "🌳")
    }

    func testNationalPark() {
        // "national park" should match before generic "park"
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "national_park"), "🏞️")
    }

    func testBeach() {
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "beach"), "🏖️")
    }

    func testHiking() {
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "hiking_trail"), "⛰️")
    }

    // MARK: - Entertainment

    func testMuseum() {
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "museum"), "🏛️")
    }

    func testMovieTheater() {
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "movie_theater"), "🎬")
    }

    func testNightclub() {
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "night_club"), "🪩")
    }

    // MARK: - Sports & Fitness

    func testGym() {
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "gym"), "💪")
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "fitness_center"), "💪")
    }

    func testYoga() {
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "yoga_studio"), "🧘")
    }

    // MARK: - Services

    func testHotel() {
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "hotel"), "🏨")
    }

    func testAirport() {
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "airport"), "✈️")
    }

    func testHospital() {
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "hospital"), "🏥")
    }

    // MARK: - Default Fallback

    func testUnknownTypeReturnsDefaultPin() {
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: ""), "📍")
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "some_random_type"), "📍")
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "xyz123"), "📍")
    }

    // MARK: - Edge Cases

    func testDimSumWithUnderscores() {
        // "dim_sum_restaurant" → normalized to "dim sum restaurant" → matches "dim sum"
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "dim_sum_restaurant"), "🥟")
    }

    func testHotPotWithUnderscores() {
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "hot_pot"), "🍲")
    }

    func testFriedChicken() {
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "fried_chicken"), "🍗")
    }

    func testBrunchSpot() {
        XCTAssertEqual(PlaceTypeEmoji.emoji(for: "brunch_restaurant"), "🥞")
    }
}
