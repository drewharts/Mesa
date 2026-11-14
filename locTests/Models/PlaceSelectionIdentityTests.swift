//
//  PlaceSelectionIdentityTests.swift
//  locTests
//
//  Tests for the rules that keep an in-sheet place page on the place that was tapped.
//

import XCTest
@testable import loc

final class PlaceSelectionIdentityTests: XCTestCase {

    private let idA = "6F1C2A10-0000-4000-8000-00000000000A"
    private let idB = "6F1C2A10-0000-4000-8000-00000000000B"

    // MARK: - Identity

    func testIdsMatch_IgnoresCase() {
        XCTAssertTrue(PlaceSelectionIdentity.idsMatch(idA, idA.lowercased()))
        XCTAssertFalse(PlaceSelectionIdentity.idsMatch(idA, idB))
        XCTAssertFalse(PlaceSelectionIdentity.idsMatch(nil, idA))
        XCTAssertFalse(PlaceSelectionIdentity.idsMatch("", ""))
    }

    func testDifferentPlacesWithoutGoogleIds_AreNotTheSamePlace() {
        // Previously "" == "" made two different list places look like one, keeping the old content.
        XCTAssertFalse(PlaceSelectionIdentity.isSamePlace(oldId: idA, oldGooglePlaceId: "", newId: idB, newGooglePlaceId: ""))
        XCTAssertFalse(PlaceSelectionIdentity.isSamePlace(oldId: idA, oldGooglePlaceId: nil, newId: idB, newGooglePlaceId: nil))
    }

    func testSameGooglePlaceUnderNewId_IsTheSamePlace() {
        XCTAssertTrue(PlaceSelectionIdentity.isSamePlace(oldId: idA, oldGooglePlaceId: "ChIJ123", newId: idB, newGooglePlaceId: "ChIJ123"))
        XCTAssertFalse(PlaceSelectionIdentity.isSamePlace(oldId: idA, oldGooglePlaceId: "ChIJ123", newId: idB, newGooglePlaceId: "ChIJ999"))
        XCTAssertTrue(PlaceSelectionIdentity.isSamePlace(oldId: idA, oldGooglePlaceId: nil, newId: idA.lowercased(), newGooglePlaceId: nil))
    }

    // MARK: - Owner stack

    func testOwnerStack_LastClaimIsTopAndReleaseRestoresPrevious() {
        var stack = PlaceDetailOwnerStack()
        let first = UUID(), second = UUID()
        stack.claim(token: first, placeId: idA)
        stack.claim(token: second, placeId: idB)
        XCTAssertTrue(stack.isTop(second))
        XCTAssertFalse(stack.isTop(first))
        stack.release(token: second)
        XCTAssertTrue(stack.isTop(first))
        // Re-claiming moves a page to the top without duplicating it.
        stack.claim(token: second, placeId: idB)
        stack.claim(token: first, placeId: idA)
        XCTAssertEqual(stack.owners.count, 2)
        XCTAssertTrue(stack.isTop(first))
    }

    // MARK: - Decisions

    private func decide(
        top: Bool = true,
        selected: String?,
        ownedGoogle: String? = "ChIJ-A",
        selectedGoogle: String? = "ChIJ-B",
        sheet: Bool = false,
        reasserts: Int = 0
    ) -> PlaceDetailOwnershipDecision {
        PlaceDetailOwnerStack.decide(
            isTopOwner: top,
            ownedPlaceId: idA,
            ownedGooglePlaceId: ownedGoogle,
            selectedPlaceId: selected,
            selectedGooglePlaceId: selectedGoogle,
            isGlobalDetailSheetPresented: sheet,
            reassertsSoFar: reasserts
        )
    }

    func testStaleWriteOfAnotherPlace_IsReasserted() {
        // Tapped A; a late load for the previous place B overwrote the selection.
        XCTAssertEqual(decide(selected: idB), .reassert)
    }

    func testMatchingOrClearedSelection_IsKept() {
        XCTAssertEqual(decide(selected: idA.lowercased()), .keep)
        XCTAssertEqual(decide(selected: nil), .keep)
    }

    func testCoveredPageOrFullDetailSheet_DoesNotFight() {
        XCTAssertEqual(decide(top: false, selected: idB), .keep)
        XCTAssertEqual(decide(selected: idB, sheet: true), .keep)
    }

    func testSameGooglePlaceUnderNewId_IsAdopted() {
        XCTAssertEqual(decide(selected: idB, ownedGoogle: "ChIJ-A", selectedGoogle: "ChIJ-A"), .adopt)
    }

    func testReassertIsCapped() {
        XCTAssertEqual(decide(selected: idB, reasserts: PlaceDetailOwnerStack.maxReasserts - 1), .reassert)
        XCTAssertEqual(decide(selected: idB, reasserts: PlaceDetailOwnerStack.maxReasserts), .keep)
    }
}
