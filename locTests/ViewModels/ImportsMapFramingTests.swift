//
//  ImportsMapFramingTests.swift
//  locTests
//
//  Tests for ImportsMapFraming: nearby-first framing, densest-cluster fallback, and span clamping.
//

import XCTest
import CoreLocation
import MapKit
@testable import loc

final class ImportsMapFramingTests: XCTestCase {

    // MARK: - Helpers

    private let unionSquare = CLLocationCoordinate2D(latitude: 40.7359, longitude: -73.9911)
    private let williamsburg = CLLocationCoordinate2D(latitude: 40.7081, longitude: -73.9571)
    private let soho = CLLocationCoordinate2D(latitude: 40.7233, longitude: -74.0030)
    private let paris = CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522)
    private let parisMarais = CLLocationCoordinate2D(latitude: 48.8590, longitude: 2.3620)
    private let tokyo = CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503)
    private let la = CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437)

    // MARK: - Focus Selection

    func testFocus_PrefersNearbyImportsPlusUser() {
        let focus = ImportsMapFraming.focusCoordinates(
            recent: [paris, williamsburg, tokyo], nearby: [], user: unionSquare
        )
        XCTAssertEqual(focus.count, 2)
        XCTAssertTrue(focus.contains { $0.latitude == williamsburg.latitude })
        XCTAssertTrue(focus.contains { $0.latitude == unionSquare.latitude })
    }

    func testFocus_NoNearbyFallsBackToDensestCluster() {
        let focus = ImportsMapFraming.focusCoordinates(
            recent: [tokyo, paris, la, parisMarais], nearby: [], user: unionSquare
        )
        XCTAssertEqual(focus.count, 2)
        XCTAssertTrue(focus.allSatisfy { $0.latitude > 48 })
    }

    func testFocus_TieGoesToMostRecent() {
        let focus = ImportsMapFraming.focusCoordinates(recent: [tokyo, paris, la], nearby: [], user: nil)
        XCTAssertEqual(focus.count, 1)
        XCTAssertEqual(focus.first?.latitude, tokyo.latitude)
    }

    func testFocus_NoImportsCentersOnUser() {
        let focus = ImportsMapFraming.focusCoordinates(recent: [], nearby: [], user: unionSquare)
        XCTAssertEqual(focus.count, 1)
        XCTAssertEqual(focus.first?.latitude, unionSquare.latitude)
    }

    func testFocus_NothingReturnsNilRegion() {
        XCTAssertNil(ImportsMapFraming.region(recent: [], nearby: [], user: nil))
    }

    func testFocus_IgnoresZeroZeroPlaceholder() {
        let zero = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let focus = ImportsMapFraming.focusCoordinates(recent: [zero, zero, paris], nearby: [], user: nil)
        XCTAssertEqual(focus.count, 1)
        XCTAssertEqual(focus.first?.latitude, paris.latitude)
    }

    // MARK: - Region

    func testRegion_SinglePlaceUsesMinimumSpan() {
        let region = ImportsMapFraming.region(containing: [paris])
        XCTAssertEqual(region?.span.latitudeDelta, ImportsMapFraming.minSpanDegrees)
        XCTAssertEqual(region?.center.latitude, paris.latitude)
    }

    func testRegion_NeverWiderThanMetro() {
        let region = ImportsMapFraming.region(containing: [paris, tokyo, la])
        XCTAssertLessThanOrEqual(region?.span.latitudeDelta ?? .infinity, ImportsMapFraming.maxSpanDegrees)
        XCTAssertLessThanOrEqual(region?.span.longitudeDelta ?? .infinity, ImportsMapFraming.maxSpanDegrees)
    }

    func testRegion_NearbyFramingContainsUserAndPlaces() {
        let region = ImportsMapFraming.region(recent: [williamsburg, soho, paris], nearby: [], user: unionSquare)!
        for c in [williamsburg, soho, unionSquare] {
            XCTAssertLessThanOrEqual(abs(c.latitude - region.center.latitude), region.span.latitudeDelta / 2)
            XCTAssertLessThanOrEqual(abs(c.longitude - region.center.longitude), region.span.longitudeDelta / 2)
        }
    }
}
