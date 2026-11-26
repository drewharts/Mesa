//
//  PhotoClusterBuilderTests.swift
//  locTests
//

import XCTest
@testable import loc

final class PhotoClusterBuilderTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func sample(_ lat: Double = 40.0, _ lng: Double = -74.0, at offset: TimeInterval? = nil,
                        acc: Double? = nil) -> PhotoSample {
        PhotoSample(latitude: lat, longitude: lng, accuracyMeters: acc,
                    capturedAt: offset.map { t0.addingTimeInterval($0) }, utcOffsetSeconds: nil)
    }

    func testSamePlaceWithinGapJoins() {
        let r = PhotoClusterBuilder.build(samples: [sample(at: 0), sample(at: 600)])
        XCTAssertEqual(r.clusters.count, 1)
    }

    func testSamePlaceAfterLongGapSplits() {
        let r = PhotoClusterBuilder.build(samples: [sample(at: 0), sample(at: 3 * 3600)])
        XCTAssertEqual(r.clusters.count, 2)
    }

    func testFarApartSplitsEvenIfClose() {
        // ~111m north
        let r = PhotoClusterBuilder.build(samples: [sample(at: 0), sample(40.001, at: 60)])
        XCTAssertEqual(r.clusters.count, 2)
    }

    func testUntimedFallsBackToLocation() {
        let r = PhotoClusterBuilder.build(samples: [sample(at: 0), sample()])
        XCTAssertEqual(r.clusters.count, 1)
    }

    func testMissingGPSIsUnassigned() {
        let r = PhotoClusterBuilder.build(samples: [nil, sample()])
        XCTAssertEqual(r.unassigned, [0])
        XCTAssertEqual(r.clusters.first?.photoIndices, [1])
    }

    func testWeightedCenterFavorsPreciseSample() {
        let c = PhotoClusterBuilder.weightedCenter(of: [sample(40.0, acc: 5), sample(40.0004, acc: 100)])
        XCTAssertLessThan(c.latitude, 40.0002)
    }

    func testParseOffset() {
        XCTAssertEqual(PhotoSample.parseOffset("-05:00"), -18000)
        XCTAssertEqual(PhotoSample.parseOffset("+05:30"), 19800)
    }
}
