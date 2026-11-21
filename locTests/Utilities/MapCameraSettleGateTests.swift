//
//  MapCameraSettleGateTests.swift
//  locTests
//
//  Tests for MapCameraSettleGate settle de-duplication.
//

import XCTest
import MapKit
@testable import loc

final class MapCameraSettleGateTests: XCTestCase {

    private func region(_ lat: Double, _ lng: Double, span: Double) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
            span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
        )
    }

    func testFirstSettleIsReported() {
        var gate = MapCameraSettleGate()
        XCTAssertTrue(gate.shouldReport(region(40, -74, span: 0.01)))
    }

    func testIdenticalSettleIsSuppressed() {
        var gate = MapCameraSettleGate()
        _ = gate.shouldReport(region(40, -74, span: 0.01))
        XCTAssertFalse(gate.shouldReport(region(40, -74, span: 0.01)))
    }

    func testTinyJitterIsSuppressed() {
        var gate = MapCameraSettleGate()
        _ = gate.shouldReport(region(40, -74, span: 0.01))
        XCTAssertFalse(gate.shouldReport(region(40.00001, -74.00001, span: 0.01001)))
    }

    func testZoomChangeIsReported() {
        var gate = MapCameraSettleGate()
        _ = gate.shouldReport(region(40, -74, span: 0.01))
        XCTAssertTrue(gate.shouldReport(region(40, -74, span: 0.005)))
    }

    func testPanIsReported() {
        var gate = MapCameraSettleGate()
        _ = gate.shouldReport(region(40, -74, span: 0.01))
        XCTAssertTrue(gate.shouldReport(region(40.005, -74, span: 0.01)))
    }

    func testSuppressedSettleDoesNotMoveBaseline() {
        var gate = MapCameraSettleGate()
        _ = gate.shouldReport(region(40, -74, span: 0.01))
        XCTAssertFalse(gate.shouldReport(region(40.00015, -74, span: 0.01)))
        XCTAssertTrue(gate.shouldReport(region(40.00025, -74, span: 0.01)))
    }
}
