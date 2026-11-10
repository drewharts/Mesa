//
//  ImageLoadingUtilityTests.swift
//  locTests
//
//  Tests for photo URL ranking and Google CDN URL classification.
//

import XCTest
@testable import loc

final class ImageLoadingUtilityTests: XCTestCase {

    /// Permanent stored URLs should sort ahead of expiring Google photo links.
    func testRankedPhotoURLsPreferStoredOverGoogle() {
        let google = "https://lh3.googleusercontent.com/p/stale=s400"
        let stored = "https://xyz.supabase.co/storage/v1/object/public/places/photo.jpg"
        let ranked = ImageLoadingUtility.rankedPhotoURLs([google, stored, google])
        XCTAssertEqual(ranked, [stored, google])
    }

    /// Empty and legacy Firebase URLs are dropped.
    func testRankedPhotoURLsDropsEmptyAndFirebase() {
        let ranked = ImageLoadingUtility.rankedPhotoURLs([
            "",
            "https://firebasestorage.googleapis.com/v0/b/old/o/x",
            "https://example.com/ok.jpg"
        ])
        XCTAssertEqual(ranked, ["https://example.com/ok.jpg"])
    }

    /// Google Places API and CDN hosts are treated as transient.
    func testTransientGoogleURLDetection() {
        XCTAssertTrue(ImageLoadingUtility.isTransientGoogleURL("https://maps.googleapis.com/maps/api/place/photo?ref=abc"))
        XCTAssertTrue(ImageLoadingUtility.isTransientGoogleURL("https://lh3.googleusercontent.com/p/abc"))
        XCTAssertFalse(ImageLoadingUtility.isTransientGoogleURL("https://xyz.supabase.co/storage/v1/object/public/photo.jpg"))
    }
}
