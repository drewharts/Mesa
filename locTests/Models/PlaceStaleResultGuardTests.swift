//
//  PlaceStaleResultGuardTests.swift
//  locTests
//
//  The guard every async place load uses before writing its result: a result requested for one place
//  must be dropped once another place is selected (the American Bar -> La Tete d'Or glitch).
//

import XCTest
@testable import loc

final class PlaceStaleResultGuardTests: XCTestCase {
    private let americanBar = UUID().uuidString
    private let laTete = UUID().uuidString

    private func isCurrent(requested: String, requestedGoogle: String? = nil, shown: String, shownGoogle: String? = nil) -> Bool {
        PlaceSelectionIdentity.isSamePlace(oldId: shown, oldGooglePlaceId: shownGoogle, newId: requested, newGooglePlaceId: requestedGoogle)
    }

    func testResultForPreviouslyShownPlaceIsDropped() {
        XCTAssertFalse(isCurrent(requested: americanBar, shown: laTete))
    }

    func testResultForShownPlaceIsApplied() {
        XCTAssertTrue(isCurrent(requested: laTete, shown: laTete))
    }

    func testUuidCaseDoesNotMakeResultStale() {
        XCTAssertTrue(isCurrent(requested: laTete.lowercased(), shown: laTete.uppercased()))
    }

    func testResolvedRowForSameGooglePlaceIsApplied() {
        XCTAssertTrue(isCurrent(requested: UUID().uuidString, requestedGoogle: "ChIJ-A", shown: americanBar, shownGoogle: "ChIJ-A"))
    }

    func testDifferentPlacesWithoutGoogleIdsAreNeverTheSame() {
        XCTAssertFalse(isCurrent(requested: americanBar, requestedGoogle: "", shown: laTete, shownGoogle: ""))
    }

    func testNothingShownDropsEveryResult() {
        XCTAssertFalse(PlaceSelectionIdentity.isSamePlace(oldId: nil, oldGooglePlaceId: nil, newId: americanBar, newGooglePlaceId: nil))
    }
}
