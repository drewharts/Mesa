//
//  TonightRankerTests.swift
//  locTests
//

import XCTest
import CoreLocation
@testable import loc

final class TonightRankerTests: XCTestCase {
    private let origin = CLLocation(latitude: 40.7128, longitude: -74.0060)

    private func place(_ id: UUID = UUID(), name: String, categories: [String], dLat: Double = 0.002) -> DetailPlace {
        var p = DetailPlace(id: id, name: name, address: nil, city: nil)
        p.categories = categories
        p.coordinate = CLLocationCoordinate2D(latitude: 40.7128 + dLat, longitude: -74.0060)
        return p
    }

    private func ranker(_ vibe: TonightVibe, status: OpenStatus = .unknown) -> TonightRanker {
        TonightRanker(vibe: vibe, origin: origin, currentUserId: "ME", friendNames: ["grace": "Grace"], usesMetric: false, openStatus: { _ in status })
    }

    func testVibeInferenceByHour() {
        XCTAssertEqual(TonightVibe.inferred(forHour: 8), .coffee)
        XCTAssertEqual(TonightVibe.inferred(forHour: 12), .lunch)
        XCTAssertEqual(TonightVibe.inferred(forHour: 19), .dinner)
        XCTAssertEqual(TonightVibe.inferred(forHour: 22), .drinks)
        XCTAssertEqual(TonightVibe.inferred(forHour: 1), .lateNight)
    }

    func testDrinksPrefersBarsOverCafes() {
        let bar = place(name: "Bar", categories: ["Cocktail bar"], dLat: 0.01)
        let cafe = place(name: "Cafe", categories: ["Coffee shop"], dLat: 0.001)
        let places = [bar.id.uuidString.lowercased(): bar, cafe.id.uuidString.lowercased(): cafe]
        let candidates = [
            TonightCandidate(placeId: bar.id.uuidString.lowercased(), saverIds: ["me"]),
            TonightCandidate(placeId: cafe.id.uuidString.lowercased(), saverIds: ["me"])
        ]
        let picks = ranker(.drinks).rank(candidates: candidates, places: places)
        XCTAssertEqual(picks.first?.place.name, "Bar")
    }

    private func rank(_ vibe: TonightVibe, _ places: [DetailPlace], status: OpenStatus = .unknown) -> [TonightPick] {
        let map = Dictionary(uniqueKeysWithValues: places.map { ($0.id.uuidString.lowercased(), $0) })
        let candidates = places.map { TonightCandidate(placeId: $0.id.uuidString.lowercased(), saverIds: ["me"]) }
        return ranker(vibe, status: status).rank(candidates: candidates, places: map)
    }

    func testClosedPlacesNeverFill() {
        let a = place(name: "A", categories: ["Wine bar"])
        XCTAssertTrue(rank(.drinks, [a], status: .closed).isEmpty)
    }

    /// Regression: "Suede" (a clothing store) was recommended for Lunch.
    func testClothingStoreNeverRecommended() {
        let suede = place(name: "Suede", categories: ["clothing_store", "establishment", "point_of_interest", "store"], dLat: 0.0005)
        for vibe in TonightVibe.allCases {
            XCTAssertTrue(rank(vibe, [suede]).isEmpty, "clothing store picked for \(vibe)")
        }
        let deli = place(name: "Deli", categories: ["Deli"], dLat: 0.01)
        XCTAssertEqual(rank(.lunch, [suede, deli]).map(\.place.name), ["Deli"])
    }

    func testNonFoodPlacesExcluded() {
        let others = [
            place(name: "Golden Gate Park", categories: ["Park", "tourist_attraction"]),
            place(name: "MoMA", categories: ["Museum"]),
            place(name: "Cuts", categories: ["hair_care", "beauty_salon"]),
            place(name: "Barber", categories: ["barber_shop"]),
            place(name: "Vino Shop", categories: ["Wine store"]),
            place(name: "Safeway", categories: ["grocery_or_supermarket", "food", "store"])
        ]
        for vibe in TonightVibe.allCases {
            XCTAssertTrue(rank(vibe, others).isEmpty, "non-food picked for \(vibe)")
        }
    }

    func testGenericOnlyCategoriesNeedFoodName() {
        let vague = place(name: "Suede", categories: ["point_of_interest", "establishment"])
        let pizza = place(name: "Joe's Pizza", categories: ["point_of_interest", "establishment", "food"])
        let none = place(name: "Blue Bottle Coffee", categories: [])
        XCTAssertEqual(rank(.lunch, [vague, pizza]).map(\.place.name), ["Joe's Pizza"])
        XCTAssertEqual(rank(.coffee, [vague, none]).map(\.place.name), ["Blue Bottle Coffee"])
    }

    func testLunchExcludesBarsAndNightlife() {
        let cocktail = place(name: "Bar", categories: ["Cocktail bar", "bar"])
        let club = place(name: "Club", categories: ["night_club"])
        let pub = place(name: "Pub", categories: ["Pub"])
        let barGrill = place(name: "Grill", categories: ["Bar & grill", "restaurant"])
        XCTAssertEqual(rank(.lunch, [cocktail, club, pub, barGrill]).map(\.place.name), ["Grill"])
    }

    func testMismatchesNeverFillAndFewerThanThreeIsOK() {
        let bar = place(name: "Bar", categories: ["Cocktail bar"])
        let cafe = place(name: "Cafe", categories: ["Coffee shop"])
        let picks = rank(.coffee, [bar, cafe])
        XCTAssertEqual(picks.map(\.place.name), ["Cafe"])
    }

    func testRadiusWidensWhenNearbyIsThin() {
        let near = place(name: "Near", categories: ["Sandwich shop"], dLat: 0.005)   // ~0.5 km
        let mid = place(name: "Mid", categories: ["Taco restaurant"], dLat: 0.1)      // ~11 km
        let far = place(name: "Far", categories: ["Ramen restaurant"], dLat: 0.3)     // ~33 km
        let tooFar = place(name: "TooFar", categories: ["Deli"], dLat: 0.6)           // ~67 km
        let names = rank(.lunch, [near, mid, far, tooFar]).map(\.place.name)
        XCTAssertEqual(Set(names), ["Near", "Mid", "Far"])
    }

    func testWholeWordMatching() {
        XCTAssertTrue(TonightRanker.matches(TonightRanker.tokenText(["wine_bar"]), "bar"))
        XCTAssertFalse(TonightRanker.matches(TonightRanker.tokenText(["barber_shop"]), "bar"))
    }

    func testReasonNamesFriend() {
        let a = place(name: "A", categories: ["Cocktail bar"])
        let reason = ranker(.drinks).reason(for: a, saverIds: ["grace"], distance: 400, status: .unknown)
        XCTAssertEqual(reason, "Grace saved this · Cocktail bar · 5 min walk")
    }

    func testFarPlacesExcluded() {
        let far = place(name: "Far", categories: ["Cocktail bar"], dLat: 1.0)
        let picks = ranker(.drinks).rank(
            candidates: [TonightCandidate(placeId: far.id.uuidString.lowercased(), saverIds: ["me"])],
            places: [far.id.uuidString.lowercased(): far]
        )
        XCTAssertTrue(picks.isEmpty)
    }

    func testGroupPickDecodesMicrosecondTimestamps() throws {
        let json = """
        {"id":"043b6b16-24a4-4132-b454-71f7de69431f","creator_id":"AAA","title":"t","place_ids":["p1","p2"],
         "decide_at":"2026-10-26T11:20:00.998653-07:00","decided_place_id":"p1","decided_at":null,"member_count":2,
         "tallies":[{"place_id":"p1","yes":1,"no":1}],"my_votes":{"P1":true}}
        """.data(using: .utf8)!
        let pick = try JSONDecoder().decode(GroupPick.self, from: json)
        XCTAssertNotNil(pick.decideAt)
        XCTAssertTrue(pick.isDecided)
        XCTAssertEqual(pick.myVote(for: "p1"), true)
        XCTAssertEqual(pick.tally(for: "p2").yes, 0)
    }
}
