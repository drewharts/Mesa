//
//  PlaceTaxonomyTests.swift
//  locTests
//
//  Tests for the tag taxonomy and the precedence rules that apply it: real category arrays from the places
//  table, the retail-on-food-place bug, primary-category precedence, and consistency of the data table.
//

import XCTest
@testable import loc

final class PlaceTaxonomyTests: XCTestCase {

    // MARK: - Helpers

    /// A real place: its name, its categories exactly as stored, and the tags it should carry.
    private struct Sample {
        let name: String
        let categories: [String]
        let expected: Set<String>

        init(_ name: String, _ categories: [String], _ expected: [String]) {
            self.name = name
            self.categories = categories
            self.expected = Set(expected)
        }
    }

    private func tags(_ name: String, _ categories: [String], corrected: String? = nil) -> [String] {
        let place = LightweightPlace(place_id: "x", name: name, latest_review_photo: nil, categories: categories, user_corrected_category: corrected)
        return ListTypeFilter.tags(of: place)
    }

    private func family(of tag: String) -> PlaceTagFamily? {
        PlaceTaxonomy.rules.first { $0.tag == tag }?.group.family
    }

    private let dae = ["Cocktail bar", "Cafe", "Event venue", "Home goods store", "Wine bar"]
    private let sullaluna = ["Italian restaurant", "Bistro", "Book store", "Coffee shop", "Restaurant"]
    private let gemHome = ["cafe", "establishment", "food", "grocery_or_supermarket", "home_goods_store", "point_of_interest", "restaurant", "store"]

    // MARK: - Real places

    private static let samples: [Sample] = [
        Sample("Dae", ["Cocktail bar", "Cafe", "Event venue", "Home goods store", "Wine bar"], ["Coffee", "Wine Bar", "Cocktails"]),
        Sample("Sullaluna", ["Italian restaurant", "Bistro", "Book store", "Coffee shop", "Restaurant"], ["Italian", "French", "Coffee"]),
        Sample("Gem Home", ["cafe", "establishment", "food", "grocery_or_supermarket", "home_goods_store", "point_of_interest", "restaurant", "store"], ["Coffee"]),
        Sample("FASAN", ["Coffee shop", "Antique store"], ["Coffee"]),
        Sample("Yesterday's News Antiques and Collectibles", ["Antique furniture store", "Costume jewelry shop", "Furniture store", "Gift shop", "Jewelry store", "Record store", "Vintage clothing store"], ["Vintage Clothing", "Jewelry", "Antiques", "Furniture", "Records"]),
        Sample("古着屋 KROOL", ["Used clothing store"], ["Vintage Clothing"]),
        Sample("Stock Vintage", ["Vintage clothing store"], ["Vintage Clothing"]),
        Sample("2nd STREET Lower East Side", ["Second hand store"], ["Vintage Clothing"]),
        Sample("2nd STREET Q Square", ["Second-hand Clothing Shop"], ["Vintage Clothing"]),
        Sample("Housing Works Bookstore", ["book_store", "cafe", "establishment", "food", "point_of_interest", "store"], ["Books"]),
        Sample("Book Club Bar", ["bar", "book_store", "cafe", "establishment", "food", "point_of_interest", "store"], ["Coffee", "Bar"]),
        Sample("Hotel Endsleigh", ["Hotel", "Restaurant"], ["Hotel"]),
        Sample("Il Maritozzo Rosso - kitchen lab", ["Restaurant", "Beer store", "Breakfast restaurant", "Brunch restaurant", "Cooking class", "Cooking school", "Gourmet grocery store", "Italian restaurant", "Roman restaurant", "Wine store"], ["Italian", "Brunch"]),
        Sample("Mitsuwa Marketplace - New Jersey", ["Japanese grocery store", "Food court", "Japanese restaurant", "Supermarket"], ["Grocery"]),
        Sample("Jongro BBQ", ["Korean barbecue restaurant"], ["Korean BBQ", "Korean"]),
        Sample("Mercer Street Books & Records", ["Book Shop", "Record Shop", "Second-hand Book Shop"], ["Books", "Records"]),
        Sample("Metrograph", ["Movie theater", "American restaurant", "Bar", "Cafe", "Lounge"], ["Theater"]),
        Sample("Shinjuku Golden-Gai", ["Tourist attraction", "Bar", "Business park", "Ramen restaurant"], ["Ramen", "Japanese", "Bar"]),
        Sample("Yamada", ["establishment", "food", "point_of_interest", "restaurant", "Japanese restaurant"], ["Japanese"]),
        Sample("Ideal Cheese Shop", ["establishment", "food", "point_of_interest", "store", "Cheese shop"], ["Cheese"]),
        Sample("Santana Row", ["shopping_mall"], ["Shopping Mall"]),
        Sample("Acker Wines", ["liquor_store"], ["Wine Shop"]),
        Sample("Glenstone", ["Modern art museum", "art_gallery", "art_museum", "tourist_attraction"], ["Museum", "Art Gallery"]),
        Sample("Forever Spa", ["Massage spa", "Foot massage parlor", "Massage therapist", "Reflexologist", "Spa", "Sports massage therapist", "Thai massage therapist"], ["Spa"]),
        Sample("NM Studio (UES)", ["gym", "point_of_interest", "health", "establishment"], ["Fitness"]),
        Sample("White Rose Collective", ["beauty_salon", "point_of_interest", "establishment"], ["Salon"]),
        Sample("Humble House", ["establishment", "furniture_store", "home_goods_store", "point_of_interest", "store"], ["Furniture", "Home Goods"]),
        Sample("Jarontiques", ["establishment", "home_goods_store", "point_of_interest", "store"], ["Home Goods"]),
        Sample("Orrifinn", ["jewelry_store", "point_of_interest", "store", "establishment"], ["Jewelry"]),
        Sample("Fabco Shoes", ["shoe_store", "point_of_interest", "store", "establishment"], ["Shoes"]),
        Sample("Savonnerie de Montmartre", ["Cosmetics store"], ["Beauty"]),
        Sample("Philip Williams Posters", ["Poster store", "Art gallery"], ["Art Supplies"]),
        Sample("Veras Market", ["Flea market"], ["Antiques"]),
        Sample("Millport Dairy", ["Grocery store"], ["Grocery"]),
        Sample("Village Butcher Shop", ["Butcher shop", "Bakery", "Deli"], ["Specialty Food"]),
        Sample("Rodolphe Le Meunier", ["Cheese shop"], ["Cheese"]),
        Sample("Restorecph", ["Vintage clothing store"], ["Vintage Clothing"]),
        Sample("Sendero Provisions Co.", ["clothing_store"], ["Clothing"]),
        Sample("Chatham Bars Inn Farm", ["Farm shop", "Plant nursery"], ["Flowers", "Grocery"]),
        Sample("Vestrahorn", ["Mountain peak"], ["Hiking"]),
        Sample("Minnewaska State Park Preserve", ["State park", "Nature preserve", "Park"], ["Park", "Nature"]),
        Sample("Lake Como", ["Lake"], ["Nature"]),
        Sample("Pre Rup Temple", ["Historical landmark", "Place of worship", "Tourist attraction"], ["Landmark", "Place of Worship"]),
        Sample("Triad Theater", ["point_of_interest", "establishment", "Theater"], ["Theater"]),
        Sample("Market Hotel", ["Event venue", "Concert hall", "Live music venue", "Night club"], ["Music Venue"]),
        Sample("Smalls Jazz Club", ["Jazz club", "Bar"], ["Music Venue"]),
        Sample("Wiggle Room", ["bar", "Night club"], ["Nightclub", "Bar"]),
        Sample("Kumano Winehouse", ["Wine bar"], ["Wine Bar"]),
        Sample("Tempête", ["Restaurant", "Bar", "Fusion restaurant", "Wine bar"], ["Wine Bar", "Bar"]),
        Sample("Bar Calico", ["Cocktail bar", "Bar"], ["Cocktails", "Bar"]),
        Sample("Télescope Café", ["Coffee shop"], ["Coffee"]),
        Sample("Happy Cow Ice Cream Shop", ["Ice cream shop"], ["Ice Cream"]),
        Sample("Win Son Bakery", ["Taiwanese restaurant", "Bakery", "Restaurant"], ["Taiwanese", "Bakery"]),
        Sample("Juno Omakase", ["Japanese restaurant"], ["Omakase", "Japanese"]),
        Sample("Ramen Momo", ["Ramen restaurant", "Asian fusion restaurant", "Japanese restaurant"], ["Ramen", "Japanese"]),
        Sample("Banh Mi Place", ["Vietnamese restaurant", "Restaurant", "Sandwich shop"], ["Vietnamese", "Sandwiches"]),
        Sample("Mit Ko Yuan Restaurant", ["Thai restaurant", "Restaurant"], ["Thai"]),
        Sample("Baan Mae", ["Southeast Asian restaurant"], ["Southeast Asian"]),
        Sample("Quique Crudo", ["Mexican restaurant"], ["Mexican"]),
        Sample("Di Fara Pizza", ["establishment", "food", "meal_takeaway", "point_of_interest", "restaurant", "Pizza restaurant"], ["Pizza"]),
        Sample("Le Bernardin", ["French restaurant", "Fine dining restaurant", "Restaurant"], ["French", "Fine Dining"]),
        Sample("Keens Steakhouse", ["Steak house"], ["Steak"]),
        Sample("CHELI MANHATTAN 浙里", ["中餐馆", "中式点心餐馆", "上海风味餐馆"], ["Chinese"]),
        Sample("Lee's Kitchen", ["Chinese restaurant", "Restaurant"], ["Chinese"]),
        Sample("Malka", ["Israeli restaurant", "Kosher restaurant", "Restaurant"], ["Israeli", "Kosher"]),
        Sample("Public Records", ["Vegan restaurant", "Cafe", "Cocktail bar", "Live music venue", "Lounge bar", "Nightclub", "Restaurant"], ["Vegan", "Coffee", "Cocktails", "Nightclub", "Bar"]),
        Sample("Thames LIDO", ["Lido", "Bar", "Function room facility", "Outdoor swimming pool", "Restaurant", "Spa", "Swimming pool"], ["Beach", "Recreation"]),
        Sample("Camping Ground", ["Campground", "Camping farm"], ["Camping"]),
        Sample("Park Cabin Company", ["Cabin rental agency", "Vacation home rental agency"], ["Vacation Rental"]),
        Sample("Hotel Neri", ["Hotel", "Executive suite rental agency", "Extended stay hotel"], ["Hotel"]),
        Sample("Eddie V's Prime Seafood", ["Seafood restaurant", "Cocktail bar", "Fine dining restaurant", "Jazz club", "Lounge bar", "New American restaurant", "Oyster bar restaurant", "Steak house"], ["American", "Steak", "Seafood", "Fine Dining", "Cocktails", "Bar"]),
        Sample("Arlene's Grocery", ["Live music venue", "Bar"], ["Music Venue"]),
        Sample("Walmart Pet Services", ["Veterinarian", "Pet groomer"], []),
        Sample("Laura Lipman Health Coaching", ["health", "point_of_interest", "establishment"], []),
        Sample("Lidkøb Østerbro", ["Thrift store", "Cafe", "Clothing store"], ["Vintage Clothing", "Clothing"]),
        Sample("Matcha 108", ["cafe", "art_gallery", "clothing_store", "tea_house"], ["Coffee", "Matcha", "Tea"]),
        Sample("Kettl Matcha Sen Mon Ten", ["point_of_interest", "establishment", "Tea house"], ["Matcha", "Tea"]),
        Sample("Slackwater Pizza SLC", ["establishment", "food", "liquor_store", "point_of_interest", "restaurant", "store"], ["Pizza"]),
        Sample("Sushi NOGI", ["establishment", "food", "grocery_or_supermarket", "point_of_interest", "restaurant", "store"], ["Sushi", "Japanese"]),
        Sample("Indian Wells Tennis Garden Stadium 1", ["stadium", "point_of_interest", "establishment"], ["Recreation"]),
    ]

    func testRealPlaces_MapToExpectedTags() {
        for sample in Self.samples {
            XCTAssertEqual(Set(tags(sample.name, sample.categories)), sample.expected, sample.name)
        }
    }

    func testRealPlaces_NeverMixDiningWithAnotherFamily() {
        for sample in Self.samples {
            let families = Set(tags(sample.name, sample.categories).compactMap(family(of:)))
            XCTAssertLessThanOrEqual(families.count, 1, "\(sample.name) mixes \(families)")
        }
    }

    // MARK: - Retail tags never land on food and drink places

    func testDae_IsDrinksAndCoffeeNotAShop() {
        let result = tags("Dae", dae)
        XCTAssertEqual(Set(result), ["Cocktails", "Coffee", "Wine Bar"])
    }

    func testSullaluna_IsItalianFrenchCoffeeNotABookshop() {
        let result = tags("Sullaluna", sullaluna)
        XCTAssertEqual(Set(result), ["Italian", "French", "Coffee"])
    }

    func testGemHome_IsCoffeeNotGroceryOrShopping() {
        let result = tags("Gem Home", gemHome)
        XCTAssertEqual(result, ["Coffee"])
    }

    func testFoodPlaces_NeverGetRetailTags() {
        let retail: Set<String> = ["Shopping", "Grocery", "Home Goods", "Books", "Furniture", "Wine Shop", "Specialty Food", "Cheese", "Vintage Clothing"]
        for categories in [dae, sullaluna, gemHome] {
            XCTAssertTrue(retail.isDisjoint(with: tags("Place", categories)), "\(categories)")
        }
    }

    func testRetailCategoryIsAllowedWhenUserCorrectedToIt() {
        XCTAssertEqual(tags("Dae", dae, corrected: "Home goods store"), ["Home Goods"])
        XCTAssertEqual(tags("Gem Home", gemHome, corrected: "Grocery store"), ["Grocery"])
    }

    func testListChips_ForTheThreeBugPlacesHaveNoShoppingChips() {
        let places = [("Dae", dae), ("Sullaluna", sullaluna), ("Gem Home", gemHome)].map {
            LightweightPlace(place_id: $0.0, name: $0.0, latest_review_photo: nil, categories: $0.1)
        }
        let titles = Set(ListTypeFilter.chips(for: places).map(\.title))
        XCTAssertTrue(titles.isDisjoint(with: ["Shopping", "Grocery", "Home Goods", "Books"]), "\(titles)")
        XCTAssertTrue(titles.contains("Coffee"))
    }

    // MARK: - Primary category precedence

    func testPrimaryCategoryDecidesTheFamily() {
        XCTAssertEqual(tags("A", ["Coffee shop", "Antique store"]), ["Coffee"])
        XCTAssertEqual(tags("A", ["Antique store", "Coffee shop"]), ["Antiques"])
        XCTAssertEqual(tags("A", ["Book store", "Cafe"]), ["Books"])
        XCTAssertEqual(tags("A", ["Cafe", "Book store"]), ["Coffee"])
    }

    func testHotelWithBarStaysAHotel() {
        XCTAssertEqual(tags("A", ["Hotel", "Bar", "Restaurant"]), ["Hotel"])
    }

    func testGenericRestaurantFirstMarksADiningPlace() {
        XCTAssertEqual(tags("A", ["Restaurant", "Home goods store", "Italian restaurant"]), ["Italian"])
    }

    func testUnorderedTypes_LodgingWinsThenDining() {
        XCTAssertEqual(tags("A", ["bar", "lodging", "establishment"]), ["Hotel"])
        XCTAssertEqual(tags("A", ["clothing_store", "cafe", "establishment"]), ["Coffee"])
        XCTAssertEqual(tags("A", ["clothing_store", "establishment", "store"]), ["Clothing"])
    }

    func testUnorderedTypes_NameConfirmedRetailBeatsSecondaryCafe() {
        XCTAssertEqual(tags("Housing Works Bookstore", ["book_store", "cafe", "establishment"]), ["Books"])
        XCTAssertEqual(tags("Some Place", ["book_store", "cafe", "establishment"]), ["Coffee"])
    }

    func testRestaurantTypeBeatsASecondaryStoreType() {
        let slackwater = ["establishment", "food", "liquor_store", "point_of_interest", "restaurant", "store"]
        XCTAssertEqual(tags("Slackwater Pizza", slackwater), ["Pizza"])
        let sushi = ["establishment", "food", "grocery_or_supermarket", "point_of_interest", "restaurant", "store"]
        XCTAssertEqual(tags("Sushi NOGI", sushi), ["Sushi", "Japanese"])
        XCTAssertEqual(tags("Plain Place", slackwater), [])
    }

    func testNameKeywordsOnlyFillInWhenCategoriesEarnedNothing() {
        XCTAssertEqual(tags("Indian Wells Stadium", ["stadium", "point_of_interest", "establishment"]), ["Recreation"])
        XCTAssertEqual(tags("Indian Wells", ["point_of_interest", "establishment"]), ["Indian"])
    }

    func testMixedLists_AppendedLabelsCountAsUnordered() {
        XCTAssertEqual(tags("A", ["establishment", "food", "point_of_interest", "store", "Cheese shop"]), ["Cheese"])
        XCTAssertEqual(tags("A", ["establishment", "food", "point_of_interest", "restaurant", "Japanese restaurant"]), ["Japanese"])
    }

    // MARK: - Mapping details

    func testSnakeCaseAndHumanLabelsMapAlike() {
        XCTAssertEqual(tags("A", ["sushi_restaurant"]), tags("A", ["Sushi restaurant"]))
        XCTAssertEqual(tags("A", ["clothing_store"]), tags("A", ["Clothing store"]))
    }

    func testVintage_UsedAndSecondHandClothingAreVintageClothing() {
        XCTAssertEqual(tags("A", ["Used clothing store"]), ["Vintage Clothing"])
        XCTAssertEqual(tags("A", ["Second hand store"]), ["Vintage Clothing"])
        XCTAssertEqual(tags("A", ["Second-hand Clothing Shop"]), ["Vintage Clothing"])
        XCTAssertEqual(tags("A", ["Thrift store"]), ["Vintage Clothing"])
        XCTAssertEqual(tags("A", ["古着屋"]), ["Vintage Clothing"])
    }

    func testAntiqueFurnitureStoreIsAntiquesAndFurniture() {
        XCTAssertEqual(tags("A", ["Antique furniture store"]), ["Antiques", "Furniture"])
    }

    func testCuisineAdjectiveYieldsToRetailNoun() {
        XCTAssertEqual(tags("A", ["Japanese grocery store"]), ["Grocery"])
        XCTAssertEqual(tags("A", ["Italian grocery store"]), ["Grocery"])
        XCTAssertEqual(tags("A", ["Japanese inn"]), ["Hotel"])
    }

    func testIrishPubAndLatinAmericanDoNotLeakIntoOtherCuisines() {
        XCTAssertEqual(tags("A", ["Irish pub"]), ["Bar"])
        XCTAssertEqual(tags("A", ["Latin American restaurant"]), ["Latin American"])
        XCTAssertEqual(tags("A", ["Southern Italian restaurant"]), ["Italian"])
    }

    func testBeerStoreIsAShopAndBeerGardenIsABrewery() {
        XCTAssertEqual(tags("A", ["Beer store"]), ["Wine Shop"])
        XCTAssertEqual(tags("A", ["Beer garden"]), ["Brewery"])
    }

    func testSkiResortIsRecreationNotAHotel() {
        XCTAssertEqual(tags("A", ["Ski resort"]), ["Recreation"])
        XCTAssertEqual(tags("A", ["Resort hotel"]), ["Hotel"])
    }

    // MARK: - Taxonomy table consistency

    func testTaxonomy_TagsAreUnique() {
        let names = PlaceTaxonomy.rules.map(\.tag)
        XCTAssertEqual(names.count, Set(names).count)
    }

    func testTaxonomy_ImpliedAndSuppressedTagsExist() {
        let names = Set(PlaceTaxonomy.rules.map(\.tag))
        for rule in PlaceTaxonomy.rules {
            XCTAssertTrue(names.isSuperset(of: rule.implies), "\(rule.tag) implies a missing tag")
            XCTAssertTrue(names.isSuperset(of: rule.suppresses), "\(rule.tag) suppresses a missing tag")
        }
        XCTAssertTrue(names.isSuperset(of: PlaceTaxonomy.specificAsianTags))
    }

    func testTaxonomy_EveryGroupHasTagsAndShoppingIsGranular() {
        for group in PlaceTagGroup.allCases {
            XCTAssertFalse(PlaceTaxonomy.rules.filter { $0.group == group }.isEmpty, group.rawValue)
        }
        let shopping = Set(PlaceTaxonomy.rules.filter { $0.group == .shopping }.map(\.tag))
        let required: Set<String> = ["Vintage Clothing", "Clothing", "Shoes", "Jewelry", "Antiques", "Furniture", "Home Goods", "Books", "Records",
                                     "Art Supplies", "Flowers", "Wine Shop", "Cheese", "Grocery", "Specialty Food", "Beauty"]
        XCTAssertTrue(shopping.isSuperset(of: required))
    }

    func testTaxonomy_TagsFromTheOldListsStillExist() {
        let names = Set(PlaceTaxonomy.rules.map(\.tag))
        let old: Set<String> = ["Bar", "Coffee", "Grocery", "Japanese", "Korean", "Lunch", "Matcha", "Mexican", "Omakase", "Pizza", "Sushi", "Ramen", "Wine Bar"]
        XCTAssertTrue(names.isSuperset(of: old))
    }

    func testTaxonomy_GenericCategoriesEarnNoTag() {
        for generic in PlaceTaxonomy.genericCategories {
            XCTAssertTrue(tags("Zzz", [generic]).isEmpty, generic)
        }
    }
}
