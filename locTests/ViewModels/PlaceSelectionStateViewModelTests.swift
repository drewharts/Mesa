//
//  PlaceSelectionStateViewModelTests.swift
//  locTests
//
//  Tests that an abandoned fresh-details fetch can't leak into the next selection.
//

import XCTest
@testable import loc

@MainActor
final class PlaceSelectionStateViewModelTests: XCTestCase {

    func testPlainSelectClearsAbandonedFreshFetchFlag() {
        let state = PlaceSelectionStateViewModel()
        var first = DetailPlace()
        first.name = "First"
        var second = DetailPlace()
        second.name = "Second"

        state.selectPlaceAndFetchDetails(first, shouldAnimateMap: false)
        XCTAssertTrue(state.isFetchingFreshDetails)

        // The user taps another place before the first fetch finishes.
        var flagSeenBySelectionHandler: Bool?
        state.onPlaceSelected = { _ in flagSeenBySelectionHandler = state.isFetchingFreshDetails }
        state.selectPlace(second, shouldAnimateMap: false)

        XCTAssertEqual(state.selectedPlace?.id, second.id)
        XCTAssertEqual(flagSeenBySelectionHandler, false, "a stale flag would skip enriching the new place")
    }
}
