//
//  TripMapAnnotationTests.swift
//  locTests
//
//  Tests for TripMapAnnotation custom Equatable (equality on 5 fields, ignoring others).
//

import XCTest
import CoreLocation
import SwiftUI
@testable import loc

final class TripMapAnnotationTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a TripMapAnnotation with default values.
    private func makeAnnotation(
        id: String = "ann-1",
        coordinate: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 37.7, longitude: -122.4),
        placeName: String = "Test Place",
        placeAddress: String? = "123 Main",
        dayIndex: Int = 0,
        stopNumber: Int = 1,
        totalStopsInDay: Int = 3,
        color: Color = .blue,
        placeId: String = "place-1",
        placeType: String? = "restaurant"
    ) -> TripMapAnnotation {
        TripMapAnnotation(
            id: id,
            coordinate: coordinate,
            placeName: placeName,
            placeAddress: placeAddress,
            dayIndex: dayIndex,
            stopNumber: stopNumber,
            totalStopsInDay: totalStopsInDay,
            color: color,
            placeId: placeId,
            placeType: placeType
        )
    }

    // MARK: - Equality (5-field check)

    func testEqual_SameFields() {
        let a = makeAnnotation()
        let b = makeAnnotation()
        XCTAssertEqual(a, b)
    }

    func testNotEqual_DifferentId() {
        let a = makeAnnotation(id: "ann-1")
        let b = makeAnnotation(id: "ann-2")
        XCTAssertNotEqual(a, b)
    }

    func testNotEqual_DifferentDayIndex() {
        let a = makeAnnotation(dayIndex: 0)
        let b = makeAnnotation(dayIndex: 1)
        XCTAssertNotEqual(a, b)
    }

    func testNotEqual_DifferentStopNumber() {
        let a = makeAnnotation(stopNumber: 1)
        let b = makeAnnotation(stopNumber: 2)
        XCTAssertNotEqual(a, b)
    }

    func testNotEqual_DifferentTotalStopsInDay() {
        let a = makeAnnotation(totalStopsInDay: 3)
        let b = makeAnnotation(totalStopsInDay: 5)
        XCTAssertNotEqual(a, b)
    }

    func testNotEqual_DifferentPlaceId() {
        let a = makeAnnotation(placeId: "place-1")
        let b = makeAnnotation(placeId: "place-2")
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Ignored Fields

    func testEqual_DifferentCoordinate() {
        let a = makeAnnotation(coordinate: CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0))
        let b = makeAnnotation(coordinate: CLLocationCoordinate2D(latitude: 40.0, longitude: -74.0))
        XCTAssertEqual(a, b)
    }

    func testEqual_DifferentPlaceName() {
        let a = makeAnnotation(placeName: "Place A")
        let b = makeAnnotation(placeName: "Place B")
        XCTAssertEqual(a, b)
    }

    func testEqual_DifferentPlaceAddress() {
        let a = makeAnnotation(placeAddress: "123 Main")
        let b = makeAnnotation(placeAddress: "456 Oak")
        XCTAssertEqual(a, b)
    }

    func testEqual_DifferentColor() {
        let a = makeAnnotation(color: .blue)
        let b = makeAnnotation(color: .red)
        XCTAssertEqual(a, b)
    }

    func testEqual_DifferentPlaceType() {
        let a = makeAnnotation(placeType: "restaurant")
        let b = makeAnnotation(placeType: "cafe")
        XCTAssertEqual(a, b)
    }
}
