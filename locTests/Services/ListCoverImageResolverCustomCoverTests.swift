import XCTest
@testable import loc

final class ListCoverImageResolverCustomCoverTests: XCTestCase {
    private let base = "https://x.supabase.co/storage/v1/object/public/list_covers/ABC"

    func testLegacyShareCardCoverIsIgnored() {
        XCTAssertNil(ListCoverImageResolver.customCoverURL("\(base)/cover.jpg"))
    }

    func testShareCardFileIsIgnored() {
        XCTAssertNil(ListCoverImageResolver.customCoverURL("\(base)/share-card.jpg?t=1"))
    }

    func testOtherImageIsKept() {
        XCTAssertEqual(ListCoverImageResolver.customCoverURL(" https://a.com/p.jpg "), "https://a.com/p.jpg")
    }

    func testEmptyIsNil() {
        XCTAssertNil(ListCoverImageResolver.customCoverURL("  "))
        XCTAssertNil(ListCoverImageResolver.customCoverURL(nil))
    }
}
