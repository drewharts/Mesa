//
//  PlaceDetailOwnership.swift
//  loc
//
//  Tracks which in-sheet place page is on screen so only that page reclaims the shared selection.
//

import Foundation

@MainActor
final class PlaceDetailOwnership: ObservableObject {
    static let shared = PlaceDetailOwnership()

    @Published private(set) var stack = PlaceDetailOwnerStack()

    private init() {}

    /// Marks a place page as visible and showing the given place.
    func claim(token: UUID, placeId: String) {
        stack.claim(token: token, placeId: placeId)
    }

    /// Removes a place page that left the screen.
    func release(token: UUID) {
        stack.release(token: token)
    }

    /// Whether the given page is the visible one.
    func isTop(_ token: UUID) -> Bool {
        stack.isTop(token)
    }
}
