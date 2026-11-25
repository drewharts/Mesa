import XCTest
@testable import loc

final class PlaceDetailVisibilityTests: XCTestCase {
    private func visible(sheet: Bool = false, page: Bool = false, tab: AppTab = .map, mapSheet: Bool = false) -> Bool {
        PlaceDetailVisibility.isVisible(isGlobalDetailSheetShowing: sheet, hasInSheetPlacePage: page, selectedTab: tab, hasMapSheet: mapSheet)
    }

    func testGlobalDetailSheetIsVisible() {
        XCTAssertTrue(visible(sheet: true))
    }

    func testNothingPresentedIsNotVisible() {
        XCTAssertFalse(visible())
    }

    func testHiddenTabSheetPageOnMapIsNotVisible() {
        XCTAssertFalse(visible(page: true, tab: .map))
    }

    func testPageInSelectedTabSheetIsVisible() {
        XCTAssertTrue(visible(page: true, tab: .explore))
    }

    func testPageInsideMapSheetIsVisible() {
        XCTAssertTrue(visible(page: true, tab: .map, mapSheet: true))
    }
}
