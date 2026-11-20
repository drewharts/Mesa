//
//  CanonicalCityResolverTests.swift
//  locTests
//
//  The city-boundary rule: boroughs -> NYC, car metros -> metro name, rural/parks -> region bucket.
//

import XCTest
@testable import loc

final class CanonicalCityResolverTests: XCTestCase {
    private func city(_ address: String, stored: String? = nil) -> String? {
        CanonicalCityResolver.resolve(address: address, storedCity: stored)
    }

    func testBoroughsAreNewYorkCity() {
        XCTAssertEqual(city("3001 Brighton 6th St, Brooklyn, NY 11235, USA"), "New York City")
        XCTAssertEqual(city("8201 3rd Ave, Brooklyn, NY 11209"), "New York City")
        XCTAssertEqual(city("136-20 Roosevelt Ave, Flushing, NY 11354, USA"), "New York City")
        XCTAssertEqual(city("4900 Broadway, New York, NY 10034"), "New York City")
        XCTAssertEqual(city("2344 Arthur Ave, Bronx, NY 10458, USA"), "New York City")
    }

    func testOutsideNewYorkCityInNewYorkStateIsUpstate() {
        XCTAssertEqual(city("Split Rock Falls, Elizabethtown, NY 12932, USA"), "Upstate NY")
        XCTAssertEqual(city("Minnewaska State Park Preserve, Kerhonkson, NY 12446"), "Upstate NY")
        XCTAssertEqual(city("Harriman State Park, Southfields, NY 10975", stored: "New York City"), "Upstate NY")
    }

    func testOtherRegionsAndCities() {
        XCTAssertEqual(city("Ricketts Glen State Park, Benton, PA 17814, USA"), "Pennsylvania")
        XCTAssertEqual(city("1 Newark Ave, Jersey City, NJ 07302, USA"), "Jersey City")
        XCTAssertEqual(city("123 Ponce de Leon Ave, Decatur, GA 30030, USA"), "Atlanta")
        XCTAssertEqual(city("1260 Pacific Coast Hwy, Santa Monica, CA 90401"), "Los Angeles")
        XCTAssertEqual(city("1 Market St, San Francisco, CA 94105"), "San Francisco")
    }

    func testMatcherUsesRuleAndUpstateAlias() {
        XCTAssertEqual(CityListMatcher.cityName(storedCity: "Kings County", address: "1 Main St, Brooklyn, NY 11201"), "New York City")
        XCTAssertEqual(CityListMatcher.cityKey("Upstate NYC"), CityListMatcher.cityKey("Upstate NY"))
    }
}
