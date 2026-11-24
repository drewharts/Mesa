import XCTest
import CoreLocation
@testable import loc

final class ExploreListRankerTests: XCTestCase {

    private func makeList(
        _ id: String, places: Int, owner: String = "u", city: String? = nil,
        created: String = "2026-01-01", lat: Double? = nil, lon: Double? = nil
    ) -> ExploreList {
        ExploreList(id: id, name: id, city: city, imageURL: nil, ownerId: owner, placeCount: places,
                    createdAt: created, updatedAt: created, latitude: lat, longitude: lon)
    }

    func testPopularFollowedOwnerBonus() {
        let lists = [makeList("big", places: 12), makeList("friend", places: 5, owner: "f")]
        let sorted = ExploreListRanker.sorted(lists, by: .popular, followedOwnerIds: ["f"])
        XCTAssertEqual(sorted.map(\.id), ["friend", "big"])
    }

    func testNewestAndMostPlaces() {
        let lists = [makeList("old", places: 9, created: "2025-01-01"), makeList("new", places: 2, created: "2026-01-01")]
        XCTAssertEqual(ExploreListRanker.sorted(lists, by: .newest, followedOwnerIds: []).first?.id, "new")
        XCTAssertEqual(ExploreListRanker.sorted(lists, by: .mostPlaces, followedOwnerIds: []).first?.id, "old")
    }

    func testCitiesGroupedByCount() {
        let lists = [makeList("a", places: 1, city: "Austin"), makeList("b", places: 1, city: "Austin"), makeList("c", places: 1, city: "Denver")]
        let cities = ExploreListRanker.cities(from: lists)
        XCTAssertEqual(cities.first?.name, "Austin")
        XCTAssertEqual(cities.first?.listCount, 2)
    }

    func testNearbyFiltersByRadius() {
        let near = makeList("near", places: 1, lat: 30.27, lon: -97.74)
        let far = makeList("far", places: 1, lat: 40.7, lon: -74.0)
        let result = ExploreListRanker.nearby([near, far], to: CLLocation(latitude: 30.26, longitude: -97.75))
        XCTAssertEqual(result.map(\.id), ["near"])
    }
}
