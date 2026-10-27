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

    func testClosedPlacesOnlyFillWhenNeeded() {
        let a = place(name: "A", categories: ["Wine bar"])
        let picks = ranker(.drinks, status: .closed).rank(
            candidates: [TonightCandidate(placeId: a.id.uuidString.lowercased(), saverIds: ["me"])],
            places: [a.id.uuidString.lowercased(): a]
        )
        XCTAssertEqual(picks.count, 1)
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
