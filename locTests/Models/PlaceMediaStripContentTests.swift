import XCTest
@testable import loc

final class PlaceMediaStripContentTests: XCTestCase {
    private func video(_ id: String, thumbnail: String) -> ExternalVideo {
        ExternalVideo(
            videoID: id, url: "https://tiktok.com/\(id)", title: nil, caption: nil, embedHTML: "",
            thumbnailURL: thumbnail,
            author: ExternalVideoAuthor(displayName: "A", url: "https://tiktok.com/@a", username: "a"),
            hashtags: [], createdAt: "2025-01-01T00:00:00Z"
        )
    }

    private func make(photos: [PhotoItem] = [], videos: [ExternalVideo] = [], failed: Set<String> = [], max: Int = 30) -> PlaceMediaStripContent {
        PlaceMediaStripContent.make(photos: photos, videos: videos, failedIDs: failed, maxItems: max)
    }

    func testEmptyInputsGiveEmptyContent() {
        XCTAssertEqual(make(), .empty)
    }

    func testVideosComeBeforePhotos() {
        let content = make(photos: [PhotoItem(url: "https://x.com/p1.jpg")], videos: [video("v1", thumbnail: "https://x.com/v1.jpg")])
        XCTAssertEqual(content.items.map(\.id), ["video_v1", "https://x.com/p1.jpg"])
        XCTAssertTrue(content.items[0].isVideo)
        XCTAssertFalse(content.items[1].isVideo)
    }

    func testPhotosWithEmptyOrBlankURLAreSkipped() {
        let content = make(photos: [PhotoItem(url: ""), PhotoItem(url: "   "), PhotoItem(url: "https://x.com/ok.jpg")])
        XCTAssertEqual(content.photoURLs, ["https://x.com/ok.jpg"])
        XCTAssertEqual(content.items.count, 1)
    }

    func testFailedPhotosAreHiddenAndGalleryIndexesStayContiguous() {
        let photos = [PhotoItem(url: "https://x.com/a.jpg"), PhotoItem(url: "https://x.com/b.jpg"), PhotoItem(url: "https://x.com/c.jpg")]
        let content = make(photos: photos, failed: ["https://x.com/a.jpg"])
        XCTAssertEqual(content.photoURLs, ["https://x.com/b.jpg", "https://x.com/c.jpg"])
        XCTAssertEqual(content.items.map(\.kind), [.photo(galleryIndex: 0), .photo(galleryIndex: 1)])
    }

    func testVideoWithoutThumbnailOrFailedIsHidden() {
        let videos = [video("v1", thumbnail: ""), video("v2", thumbnail: "https://x.com/v2.jpg"), video("v3", thumbnail: "https://x.com/v3.jpg")]
        let content = make(videos: videos, failed: ["video_v3"])
        XCTAssertEqual(content.items.map(\.id), ["video_v2"])
        XCTAssertEqual(content.items.first?.kind, .externalVideo(videoID: "v2"))
    }

    func testPhotoDuplicatingVideoThumbnailIsDropped() {
        let content = make(photos: [PhotoItem(url: "https://x.com/v1.jpg")], videos: [video("v1", thumbnail: "https://x.com/v1.jpg")])
        XCTAssertEqual(content.items.count, 1)
        XCTAssertTrue(content.photoURLs.isEmpty)
    }

    func testDuplicatePhotosAreCollapsed() {
        let content = make(photos: [PhotoItem(url: "https://x.com/a.jpg"), PhotoItem(url: "https://x.com/a.jpg")])
        XCTAssertEqual(content.items.count, 1)
    }

    func testGalleryVideoNeedsThumbnailAndVideoURL() {
        let good = PhotoItem(videoUrl: "https://x.com/v.mp4", thumbnailUrl: "https://x.com/t.jpg")
        let noThumb = PhotoItem(videoUrl: "https://x.com/w.mp4", thumbnailUrl: nil)
        let content = make(photos: [good, noThumb])
        XCTAssertEqual(content.items.count, 1)
        XCTAssertEqual(content.items.first?.kind, .galleryVideo(url: "https://x.com/v.mp4"))
        XCTAssertTrue(content.photoURLs.isEmpty)
    }

    func testItemsAreCappedButGalleryKeepsAllPhotos() {
        let photos = (0..<5).map { PhotoItem(url: "https://x.com/\($0).jpg") }
        let content = make(photos: photos, max: 3)
        XCTAssertEqual(content.items.count, 3)
        XCTAssertEqual(content.photoURLs.count, 5)
    }
}
