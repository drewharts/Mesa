//
//  SavedLibraryBuilderTests.swift
//  locTests
//
//  Tests for the auto_sort_saved prototype: city detection, type and cuisine rules, dedupe,
//  small-city folding, and smart groups.
//

import XCTest
@testable import loc

final class SavedLibraryBuilderTests: XCTestCase {

    // MARK: - Helpers

    private let unionSquare = (lat: 40.7359, lon: -73.9911)

    private func place(
        _ id: String, _ name: String, address: String? = nil, city: String? = nil,
        lat: Double? = nil, lon: Double? = nil, categories: [String] = [],
        google: String? = nil, dinner: Bool = false, addedAt: Date? = nil,
        source: SavedPlaceInput.Source = .list
    ) -> SavedPlaceInput {
        SavedPlaceInput(
            id: id, name: name, address: address, storedCity: city, latitude: lat, longitude: lon,
            categories: categories, userCorrectedCategory: nil, googlePlaceId: google,
            isDinnerSpot: dinner, addedAt: addedAt, sources: [source]
        )
    }

    // MARK: - Address -> city

    func testLocality_USAddressWithAndWithoutCountry() {
        XCTAssertEqual(SavedLibraryBuilder.locality(fromAddress: "181 Essex St, New York, NY 10002"), "New York")
        XCTAssertEqual(SavedLibraryBuilder.locality(fromAddress: "551 W 400 N, Salt Lake City, UT 84116, USA"), "Salt Lake City")
        XCTAssertEqual(SavedLibraryBuilder.locality(fromAddress: "Peekamoose Rd, Sundown, NY 12740"), "Sundown")
        XCTAssertEqual(SavedLibraryBuilder.locality(fromAddress: "Brooklyn, NY"), "Brooklyn")
    }

    func testLocality_International() {
        XCTAssertEqual(SavedLibraryBuilder.locality(fromAddress: "43 Rue Ramey, 75018 Paris, France"), "Paris")
        XCTAssertEqual(SavedLibraryBuilder.locality(fromAddress: "2519 R. Notre Dame O, Montréal, QC H3J 1N4, Canada"), "Montréal")
        XCTAssertEqual(SavedLibraryBuilder.locality(fromAddress: "20-11 Sarugakucho, Shibuya, Tokyo 150-0033, Japan"), "Tokyo")
        XCTAssertEqual(SavedLibraryBuilder.locality(fromAddress: "11th Floor, The Residences, 38 Sukhumvit 38 Alley, Phra Khanong, Khlong Toei, Bangkok 10110, Thailand"), "Bangkok")
        XCTAssertEqual(SavedLibraryBuilder.locality(fromAddress: "10 Downing St, London SW1A 2AA, UK"), "London")
        XCTAssertEqual(SavedLibraryBuilder.locality(fromAddress: "BARRA DE NAVIDAD, K, México 200 Manzana 7.5, 48898 La Manzanilla, Jal., Mexico"), "La Manzanilla")
    }

    func testLocality_NoUsableAddress() {
        XCTAssertNil(SavedLibraryBuilder.locality(fromAddress: nil))
        XCTAssertNil(SavedLibraryBuilder.locality(fromAddress: ""))
        XCTAssertNil(SavedLibraryBuilder.locality(fromAddress: "Somewhere"))
    }

    func testCity_StoredCityWinsAndNYCIsNormalized() {
        XCTAssertEqual(SavedLibraryBuilder.city(storedCity: "Paris", address: "43 Rue Ramey, 75018 Paris, France")?.city, "Paris")
        XCTAssertEqual(SavedLibraryBuilder.city(storedCity: "New York", address: "913 Broadway, New York, NY 10010, USA")?.city, "New York City")
        let brooklyn = SavedLibraryBuilder.city(storedCity: "New York City", address: "1928 Bath Ave, Brooklyn, NY 11214, USA")
        XCTAssertEqual(brooklyn?.city, "New York City")
        XCTAssertEqual(brooklyn?.area, "Brooklyn")
        let flushing = SavedLibraryBuilder.city(storedCity: "", address: "136-20 Roosevelt Ave, Flushing, NY 11354")
        XCTAssertEqual(flushing?.city, "New York City")
        XCTAssertEqual(flushing?.area, "Flushing")
    }

    func testCity_CoarseStoredCityFallsBackToAddress() {
        let kings = SavedLibraryBuilder.city(storedCity: "Kings County", address: "56 Bogart St, Brooklyn, NY 11206")
        XCTAssertEqual(kings?.city, "New York City")
        XCTAssertEqual(kings?.area, "Brooklyn")
        XCTAssertEqual(SavedLibraryBuilder.city(storedCity: "Greater London", address: nil)?.city, "London")
        XCTAssertEqual(SavedLibraryBuilder.city(storedCity: "Oregon", address: "McKenzie River, Oregon, USA")?.city, "McKenzie River")
    }

    func testLocality_CountryOnlyOrStreetOnlyIsRejected() {
        XCTAssertNil(SavedLibraryBuilder.locality(fromAddress: "Lake Como, Italy").flatMap { $0 == "Italy" ? $0 : nil })
        XCTAssertEqual(SavedLibraryBuilder.locality(fromAddress: "Lake Como, Italy"), "Lake Como")
        XCTAssertNil(SavedLibraryBuilder.locality(fromAddress: "Faroe Islands, "))
        XCTAssertEqual(SavedLibraryBuilder.locality(fromAddress: "Kastro, Greece"), "Kastro")
    }

    func testCity_BoroughNameOutsideNewYorkIsLeftAlone() {
        XCTAssertEqual(SavedLibraryBuilder.city(storedCity: "", address: "100 Main St, Brooklyn, MI 49230")?.city, "Brooklyn")
        XCTAssertEqual(SavedLibraryBuilder.city(storedCity: "Corona", address: "1 Main St, Corona, CA 92882")?.city, "Corona")
    }

    // MARK: - Type rules

    func testClassify_DisplayNameListsUsePrimaryType() {
        XCTAssertEqual(SavedLibraryBuilder.classify(categories: ["Cocktail bar"], corrected: nil, name: "Oddball"), .bars)
        XCTAssertEqual(SavedLibraryBuilder.classify(categories: ["Steak house", "Bar", "Korean restaurant"], corrected: nil, name: "COTE"), .restaurants)
        XCTAssertEqual(SavedLibraryBuilder.classify(categories: ["Movie theater", "American restaurant", "Bar"], corrected: nil, name: "Metrograph"), .sights)
        XCTAssertEqual(SavedLibraryBuilder.classify(categories: ["Boot store"], corrected: nil, name: "Texas Traditions"), .shops)
        XCTAssertEqual(SavedLibraryBuilder.classify(categories: ["State park", "Park", "Tourist attraction"], corrected: nil, name: "Ricketts Glen"), .sights)
        XCTAssertEqual(SavedLibraryBuilder.classify(categories: ["Coffee shop"], corrected: nil, name: "Devoción"), .coffee)
        XCTAssertEqual(SavedLibraryBuilder.classify(categories: ["Ice cream shop"], corrected: nil, name: "Van Leeuwen"), .coffee)
        XCTAssertEqual(SavedLibraryBuilder.classify(categories: ["hotel", "Resort hotel", "Spa"], corrected: nil, name: "Four Seasons"), .stays)
    }

    func testClassify_LegacyGoogleTypesUsePriority() {
        XCTAssertEqual(SavedLibraryBuilder.classify(categories: ["bar", "establishment", "food", "point_of_interest", "restaurant"], corrected: nil, name: "Le Vin Papillon"), .restaurants)
        XCTAssertEqual(SavedLibraryBuilder.classify(categories: ["establishment", "food", "point_of_interest", "restaurant"], corrected: nil, name: "Semma"), .restaurants)
        XCTAssertEqual(SavedLibraryBuilder.classify(categories: ["clothing_store", "establishment", "point_of_interest", "store"], corrected: nil, name: "Suede"), .shops)
        XCTAssertEqual(SavedLibraryBuilder.classify(categories: ["establishment", "natural_feature"], corrected: nil, name: "Mount Amagi"), .sights)
        XCTAssertEqual(SavedLibraryBuilder.classify(categories: ["lodging"], corrected: nil, name: "Hôtel"), .stays)
    }

    func testClassify_FallsBackToNameThenOther() {
        XCTAssertEqual(SavedLibraryBuilder.classify(categories: [], corrected: nil, name: "Joe's Pizza"), .restaurants)
        XCTAssertEqual(SavedLibraryBuilder.classify(categories: [], corrected: nil, name: "148 E 19th St"), .other)
        XCTAssertEqual(SavedLibraryBuilder.classify(categories: ["Wedding venue"], corrected: nil, name: "Hall"), .other)
    }

    func testClassify_UserCorrectionWins() {
        XCTAssertEqual(SavedLibraryBuilder.classify(categories: ["restaurant"], corrected: "Wine bar", name: "X"), .bars)
    }

    // MARK: - Cuisine

    func testCuisine() {
        XCTAssertEqual(SavedLibraryBuilder.cuisine(categories: ["Japanese restaurant"], corrected: nil), "Japanese")
        XCTAssertEqual(SavedLibraryBuilder.cuisine(categories: ["japanese_restaurant"], corrected: nil), "Japanese")
        XCTAssertEqual(SavedLibraryBuilder.cuisine(categories: ["Steak house", "Bar", "Fine dining restaurant", "Korean restaurant"], corrected: nil), "Steakhouse")
        XCTAssertEqual(SavedLibraryBuilder.cuisine(categories: ["Fine dining restaurant", "Korean restaurant"], corrected: nil), "Korean")
        XCTAssertEqual(SavedLibraryBuilder.cuisine(categories: ["Sushi restaurant"], corrected: nil), "Sushi")
        XCTAssertEqual(SavedLibraryBuilder.cuisine(categories: ["New American restaurant"], corrected: nil), "New American")
        XCTAssertNil(SavedLibraryBuilder.cuisine(categories: ["establishment", "food", "point_of_interest", "restaurant"], corrected: nil))
        XCTAssertEqual(SavedLibraryBuilder.cuisine(categories: ["Authentic Japanese restaurant"], corrected: nil), "Japanese")
        XCTAssertEqual(SavedLibraryBuilder.cuisine(categories: ["food", "restaurant"], corrected: nil, name: "Joe's Pizza"), "Pizza")
    }

    // MARK: - Dedupe

    func testDedupe_SameIdInSeveralListsAndImport() {
        let added = Date(timeIntervalSince1970: 1_000_000)
        let merged = SavedLibraryBuilder.dedupe([
            place("A", "Semma", source: .list),
            place("a", "Semma", source: .list),
            place("A", "Semma", addedAt: added, source: .imported)
        ])
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged[0].sources, [.list, .imported])
        XCTAssertEqual(merged[0].addedAt, added)
    }

    func testDedupe_SameGoogleIdOrSameNameNearby() {
        let merged = SavedLibraryBuilder.dedupe([
            place("1", "Semma", google: "g1"),
            place("2", "Semma NYC", google: "g1"),
            place("3", "Oddball", lat: 40.7260, lon: -73.9790),
            place("4", "ODDBALL", lat: 40.7261, lon: -73.9791),
            place("5", "Oddball", lat: 34.05, lon: -118.24)
        ])
        XCTAssertEqual(merged.map(\.id), ["1", "3", "5"])
    }

    // MARK: - Library

    func testBuild_GroupsByCityThenSortsBiggestFirst() {
        let lib = SavedLibraryBuilder.build([
            place("1", "Semma", address: "60 Greenwich Ave, New York, NY 10011, USA", city: "New York", lat: 40.737, lon: -74.0, categories: ["restaurant"]),
            place("2", "La Chacra", address: "1928 Bath Ave, Brooklyn, NY 11214, USA", city: "New York City", lat: 40.60, lon: -74.0, categories: ["restaurant"]),
            place("3", "Oddball", address: "188 Avenue B, New York, NY 10009", lat: 40.726, lon: -73.979, categories: ["Cocktail bar"]),
            place("4", "Mehmet", address: "43 Rue Ramey, 75018 Paris, France", city: "Paris", lat: 48.89, lon: 2.35, categories: ["restaurant"])
        ], userLocation: nil)
        XCTAssertEqual(lib.totalCount, 4)
        XCTAssertEqual(lib.cities.map(\.name), ["New York City", "Paris"])
        XCTAssertEqual(lib.cities[0].typeCounts.map(\.type), [.restaurants, .bars])
        XCTAssertEqual(lib.cities[0].places.first { $0.id == "2" }?.area, "Brooklyn")
    }

    func testBuild_FoldsTinyNearbyCityAndOrphansIntoBigCity() {
        var inputs: [SavedPlaceInput] = (0..<6).map { i in
            place("ny\(i)", "NY \(i)", address: "\(i) Broadway, New York, NY 10010", lat: 40.73 + Double(i) * 0.001, lon: -73.99, categories: ["restaurant"])
        }
        inputs.append(place("hob", "Hoboken spot", address: "1 Washington St, Hoboken, NJ 07030", lat: 40.744, lon: -74.027, categories: ["restaurant"]))
        inputs.append(place("orph", "No address", lat: 40.75, lon: -73.98, categories: ["restaurant"]))
        inputs.append(place("far", "Nowhere", lat: 10, lon: 10))
        let lib = SavedLibraryBuilder.build(inputs, userLocation: nil)
        XCTAssertEqual(lib.cities.map(\.name), ["New York City", SavedLibraryBuilder.unknownCityName])
        let nyc = lib.cities[0]
        XCTAssertEqual(nyc.places.count, 8)
        XCTAssertEqual(nyc.places.first { $0.id == "hob" }?.area, "Hoboken")
    }

    func testBuild_SmartGroups() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let lib = SavedLibraryBuilder.build([
            place("1", "Semma", city: "New York", lat: 40.737, lon: -74.0, categories: ["Indian restaurant"], dinner: true, addedAt: now.addingTimeInterval(-2 * 86_400), source: .imported),
            place("2", "Lord's", city: "New York", lat: 40.729, lon: -73.997, categories: ["British restaurant"], dinner: true),
            place("3", "Oddball", city: "New York", lat: 40.726, lon: -73.979, categories: ["Cocktail bar"], addedAt: now.addingTimeInterval(-30 * 86_400), source: .imported),
            place("4", "Mehmet", city: "Paris", lat: 48.89, lon: 2.35, categories: ["restaurant"], dinner: true)
        ], userLocation: unionSquare, now: now)
        let byKind = Dictionary(uniqueKeysWithValues: lib.smartGroups.map { ($0.kind, $0) })
        XCTAssertEqual(byKind[.nearYou]?.places.map(\.id).sorted(), ["1", "2", "3"])
        XCTAssertEqual(byKind[.thisWeek]?.places.map(\.id), ["1"])
        XCTAssertEqual(byKind[.dinner]?.title, "Dinner in NYC")
        XCTAssertEqual(byKind[.dinner]?.places.map(\.id).sorted(), ["1", "2"])
    }

    func testBuild_NoLocationSkipsNearYouAndUsesBiggestCityForDinner() {
        let lib = SavedLibraryBuilder.build([
            place("1", "A", city: "Paris", lat: 48.85, lon: 2.35, categories: ["restaurant"], dinner: true),
            place("2", "B", city: "Paris", lat: 48.86, lon: 2.34, categories: ["restaurant"], dinner: true),
            place("3", "C", city: "Tokyo", lat: 35.6, lon: 139.7, categories: ["restaurant"], dinner: true)
        ], userLocation: nil)
        XCTAssertNil(lib.smartGroups.first { $0.kind == .nearYou })
        XCTAssertNil(lib.smartGroups.first { $0.kind == .thisWeek })
        XCTAssertEqual(lib.smartGroups.first { $0.kind == .dinner }?.title, "Dinner in Paris")
    }

    func testBuild_EmptyInput() {
        XCTAssertEqual(SavedLibraryBuilder.build([], userLocation: unionSquare), .empty)
    }

    // MARK: - Timestamps

    func testParseTimestamp_SupabaseFormats() {
        let expected = Date(timeIntervalSince1970: 1_762_905_600) // 2025-11-12T00:00:00Z
        XCTAssertEqual(SavedLibraryBuilder.parseTimestamp("2025-11-12T00:00:00"), expected)
        XCTAssertEqual(SavedLibraryBuilder.parseTimestamp("2025-11-12T00:00:00Z"), expected)
        XCTAssertEqual(SavedLibraryBuilder.parseTimestamp("2025-11-12 00:00:00+00:00"), expected)
        XCTAssertEqual(SavedLibraryBuilder.parseTimestamp("2025-11-12T00:00:00.123456")!.timeIntervalSince1970, 1_762_905_600.123, accuracy: 0.001)
        XCTAssertNil(SavedLibraryBuilder.parseTimestamp("not a date"))
        XCTAssertNil(SavedLibraryBuilder.parseTimestamp(nil))
    }
}
