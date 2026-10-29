//
//  PlaceIdGuard.swift
//  loc
//
//  Search suggestions start with a shared sentinel id (DetailPlace.placeholderUUID) until the
//  backend returns the real place. Nothing may ever be persisted against that sentinel, or
//  unrelated rows collapse onto one place (the "Poppy reviews" bug). Every write path calls
//  `PlaceIdGuard.requireReal` and UI entry points resolve first via `ensureResolved`.
//

import Foundation

enum PlaceIdError: LocalizedError {
    case stillLoading

    var errorDescription: String? {
        "This place is still loading. Try again in a moment."
    }
}

enum PlaceIdGuard {
    static let placeholderId = DetailPlace.placeholderUUID.uuidString

    static func isPlaceholder(_ id: String?) -> Bool {
        guard let id else { return false }
        return id.caseInsensitiveCompare(placeholderId) == .orderedSame
    }

    /// Throws if `id` is the shared placeholder id.
    static func requireReal(_ id: String) throws {
        if isPlaceholder(id) { throw PlaceIdError.stillLoading }
    }
}

extension PlaceRepository {
    /// Returns `place` unchanged when it already has a real id. Otherwise resolves it through
    /// the backend (with a short retry) and returns the resolved copy. Throws
    /// `PlaceIdError.stillLoading` if a real id can't be obtained.
    func ensureResolved(_ place: DetailPlace) async throws -> DetailPlace {
        guard place.hasPlaceholderID else { return place }
        let delaysMs: [UInt64] = [0, 600, 1_200]
        for delay in delaysMs {
            if delay > 0 { try? await Task.sleep(nanoseconds: delay * 1_000_000) }
            if let resolved = try? await resolvePlace(
                googlePlaceId: place.googlePlaceId,
                fallbackId: place.googlePlaceId ?? "",
                existingPlace: place
            ), !resolved.hasPlaceholderID {
                return resolved
            }
        }
        throw PlaceIdError.stillLoading
    }
}
