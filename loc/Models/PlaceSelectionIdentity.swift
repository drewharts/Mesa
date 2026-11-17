//
//  PlaceSelectionIdentity.swift
//  loc
//
//  Pure rules for deciding whether two selections are the same place, and which in-sheet place page
//  owns the app-wide selection. Kept free of SwiftUI so it can be unit tested.
//

import Foundation

/// Identity comparisons for place selection.
enum PlaceSelectionIdentity {
    /// Returns true when both ids are present and equal, ignoring UUID casing.
    static func idsMatch(_ lhs: String?, _ rhs: String?) -> Bool {
        guard let lhs, let rhs, !lhs.isEmpty, !rhs.isEmpty else { return false }
        return lhs.caseInsensitiveCompare(rhs) == .orderedSame
    }

    /// Returns true when two selections are the same place: same id, or the same non-empty Google
    /// Place ID (a placeholder or duplicate row resolving to the real one). Empty Google ids never match.
    static func isSamePlace(
        oldId: String?,
        oldGooglePlaceId: String?,
        newId: String?,
        newGooglePlaceId: String?
    ) -> Bool {
        if idsMatch(oldId, newId) { return true }
        guard let oldGoogle = oldGooglePlaceId, let newGoogle = newGooglePlaceId,
              !oldGoogle.isEmpty, !newGoogle.isEmpty else { return false }
        return oldGoogle == newGoogle
    }
}

/// What an in-sheet place page should do when the app-wide selection no longer matches its place.
enum PlaceDetailOwnershipDecision: Equatable {
    /// Leave the selection alone.
    case keep
    /// The selection is the same place under a new id; take it as this page's place.
    case adopt
    /// The selection was overwritten by a stale or unrelated write; select this page's place again.
    case reassert
}

/// Stack of live in-sheet place pages. The most recently claimed page is the visible one and the
/// only one allowed to put its place back when something else overwrites the selection.
struct PlaceDetailOwnerStack: Equatable {
    /// One live place page and the place it shows.
    struct Owner: Equatable {
        let token: UUID
        let placeId: String
    }

    /// Most stale write-backs one page makes before giving up (guards against a ping-pong).
    static let maxReasserts = 3

    private(set) var owners: [Owner] = []

    /// The visible page, if any.
    var top: Owner? { owners.last }

    /// Marks a page as visible and showing the given place, moving it to the top.
    mutating func claim(token: UUID, placeId: String) {
        owners.removeAll { $0.token == token }
        owners.append(Owner(token: token, placeId: placeId))
    }

    /// Removes a page that is no longer on screen.
    mutating func release(token: UUID) {
        owners.removeAll { $0.token == token }
    }

    /// Whether the given page is the visible one.
    func isTop(_ token: UUID) -> Bool {
        top?.token == token
    }

    /// Decides how a page reacts to the current selection.
    static func decide(
        isTopOwner: Bool,
        ownedPlaceId: String,
        ownedGooglePlaceId: String?,
        selectedPlaceId: String?,
        selectedGooglePlaceId: String?,
        isGlobalDetailSheetPresented: Bool,
        reassertsSoFar: Int
    ) -> PlaceDetailOwnershipDecision {
        // Cleared selection (dismissal, city redirect) or a match: nothing to do.
        guard let selectedPlaceId, !idsMatchOrEmpty(ownedPlaceId, selectedPlaceId) else { return .keep }
        // A covered page, or the full place sheet taking over, doesn't own the selection.
        guard isTopOwner, !isGlobalDetailSheetPresented else { return .keep }
        if PlaceSelectionIdentity.isSamePlace(
            oldId: ownedPlaceId,
            oldGooglePlaceId: ownedGooglePlaceId,
            newId: selectedPlaceId,
            newGooglePlaceId: selectedGooglePlaceId
        ) {
            return .adopt
        }
        return reassertsSoFar < maxReasserts ? .reassert : .keep
    }

    /// Treats a matching or empty selected id as "nothing to reconcile".
    private static func idsMatchOrEmpty(_ owned: String, _ selected: String) -> Bool {
        selected.isEmpty || PlaceSelectionIdentity.idsMatch(owned, selected)
    }
}
