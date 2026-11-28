//
//  PlaceCandidateRankerTests.swift
//  locTests
//

import XCTest
@testable import loc

final class PlaceCandidateRankerTests: XCTestCase {
    private func place(_ name: String, lat: Double, types: [String]?, hours: PlaceOpeningHours? = nil) -> NearbyPlaceFeature {
        let props = NearbyPlaceProperties(
            address: "", distanceMeters: nil, name: name, source: nil, businessStatus: nil,
            createdAt: nil, openNow: nil, permanentlyClosed: nil, photoReference: nil,
            priceLevel: nil, rating: nil, types: types, updatedAt: nil, userRatingsTotal: nil,
            regularOpeningHours: hours, description: nil, id: name, placeId: nil)
        return NearbyPlaceFeature(
            geometry: NearbyPlaceGeometry(coordinates: [-74.0, lat], type: "Point"),
            properties: props, type: "Feature")
    }

    func testRestaurantBeatsSlightlyCloserBank() {
        let r = PlaceCandidateRanker.rank(
            [place("Bank", lat: 40.0, types: ["bank"]), place("Diner", lat: 40.0003, types: ["restaurant"])],
            centerLatitude: 40.0, centerLongitude: -74.0)
        XCTAssertEqual(r.places.first?.properties.name, "Diner")
        XCTAssertTrue(r.hasConfidentPick)
    }

    func testCloseTieIsNotConfident() {
        let r = PlaceCandidateRanker.rank(
            [place("A", lat: 40.0001, types: ["restaurant"]), place("B", lat: 40.0001, types: ["bar"])],
            centerLatitude: 40.0, centerLongitude: -74.0)
        XCTAssertFalse(r.hasConfidentPick)
    }

    func testClosedPlaceIsPenalized() {
        // Open Mondays 09:00-17:00 only (day 1); capture 2023-11-14 is a Tuesday -> closed.
        let hours = PlaceOpeningHours(periods: [.init(open: .init(day: 1, hour: 9, minute: 0),
                                                      close: .init(day: 1, hour: 17, minute: 0))])
        let date = Date(timeIntervalSince1970: 1_700_000_000) // Tue 2023-11-14 22:13 UTC
        let r = PlaceCandidateRanker.rank(
            [place("Closed", lat: 40.0, types: ["cafe"], hours: hours), place("Open", lat: 40.0003, types: ["cafe"])],
            centerLatitude: 40.0, centerLongitude: -74.0, capturedAt: date, utcOffsetSeconds: 0)
        XCTAssertEqual(r.places.first?.properties.name, "Open")
    }

    func testSearchRadii() {
        XCTAssertEqual(PlaceCandidateRanker.searchRadii(bestAccuracyMeters: nil), [60, 150, 300])
        XCTAssertEqual(PlaceCandidateRanker.searchRadii(bestAccuracyMeters: 120), [120, 150, 300])
        XCTAssertEqual(PlaceCandidateRanker.searchRadii(bestAccuracyMeters: 500), [150, 300])
    }

    func testOpeningHoursOvernightWrap() {
        let hours = PlaceOpeningHours(periods: [.init(open: .init(day: 5, hour: 20, minute: 0),
                                                      close: .init(day: 6, hour: 2, minute: 0))])
        XCTAssertEqual(hours.isOpen(weekday: 6, minuteOfDay: 60), true)
        XCTAssertEqual(hours.isOpen(weekday: 6, minuteOfDay: 180), false)
    }
}
