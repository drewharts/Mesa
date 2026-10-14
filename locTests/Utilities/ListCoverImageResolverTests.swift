//
//  ListCoverImageResolverTests.swift
//  locTests
//
//  Tests for ListCoverImageResolver: candidate ordering, de-duplication,
//  and skipping images that failed to load.
//

import XCTest
@testable import loc

final class ListCoverImageResolverTests: XCTestCase {

    // MARK: - Helpers

    private func place(
        _ id: String,
        video: String? = nil,
        review: String? = nil,
        thumbnail: String? = nil
    ) -> LightweightPlace {
        LightweightPlace(
            place_id: id,
            name: id,
            latest_review_photo: review,
            content_url: video,
            thumbnail_url: thumbnail
        )
    }

    private func candidates(preview: [String]? = nil, places: [LightweightPlace], videoThumbs: [String: String] = [:]) -> [String] {
        ListCoverImageResolver.candidateURLs(previewPhotos: preview, places: places, videoThumbnail: { videoThumbs[$0] })
    }

    // MARK: - Candidate Ordering

    func testPreviewPhotosComeBeforePlaceImages() {
        let result = candidates(preview: ["https://a.com/p.jpg"], places: [place("1", review: "https://a.com/r.jpg")])
        XCTAssertEqual(result, ["https://a.com/p.jpg", "https://a.com/r.jpg"])
    }

    func testPlaceSourcesOrderedVideoThenReviewThenThumbnail() {
        let p = place("1", video: "https://tiktok.com/v", review: "https://a.com/r.jpg", thumbnail: "https://a.com/t.jpg")
        let result = candidates(places: [p], videoThumbs: ["https://tiktok.com/v": "https://a.com/v.jpg"])
        XCTAssertEqual(result, ["https://a.com/v.jpg", "https://a.com/r.jpg", "https://a.com/t.jpg"])
    }

    func testUncachedVideoThumbnailIsSkipped() {
        let result = candidates(places: [place("1", video: "https://tiktok.com/v", review: "https://a.com/r.jpg")])
        XCTAssertEqual(result, ["https://a.com/r.jpg"])
    }

    // MARK: - Cleanup

    func testDuplicatesAndBlanksAreRemoved() {
        let result = candidates(
            preview: ["https://a.com/r.jpg", " ", ""],
            places: [place("1", review: "https://a.com/r.jpg", thumbnail: ""), place("2", thumbnail: "https://a.com/t.jpg")]
        )
        XCTAssertEqual(result, ["https://a.com/r.jpg", "https://a.com/t.jpg"])
    }

    func testNoImagesReturnsEmpty() {
        XCTAssertEqual(candidates(preview: nil, places: [place("1")]), [])
    }

    // MARK: - Visible URLs

    func testVisibleURLsSkipFailedAndFallBackToLaterCandidates() {
        let all = ["https://a.com/1.jpg", "https://a.com/2.jpg", "https://a.com/3.jpg", "https://a.com/4.jpg"]
        let visible = ListCoverImageResolver.visibleURLs(candidates: all, failed: ["https://a.com/2.jpg"])
        XCTAssertEqual(visible, ["https://a.com/1.jpg", "https://a.com/3.jpg", "https://a.com/4.jpg"])
    }

    func testVisibleURLsReturnsFewerWhenCandidatesRunOut() {
        let visible = ListCoverImageResolver.visibleURLs(candidates: ["https://a.com/1.jpg", "https://a.com/2.jpg"], failed: ["https://a.com/1.jpg"])
        XCTAssertEqual(visible, ["https://a.com/2.jpg"])
    }
}
