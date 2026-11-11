//
//  ListPlaceOptimisticUpdate.swift
//  loc
//
//  Pure helpers for the optimistic add-to-list cache update and its rollback.
//  Kept free of view model state so they can be unit tested.
//

import Foundation

enum ListPlaceOptimisticUpdate {
    /// Inserts `place` at the front of `places` unless a place with the same id is already there.
    /// Returns the new array and whether an insert happened.
    static func applyingAdd(_ place: LightweightPlace, to places: [LightweightPlace]?) -> (places: [LightweightPlace], didInsert: Bool) {
        guard var existing = places else { return ([place], true) }
        if existing.contains(where: { sameId($0.place_id, place.place_id) }) {
            return (existing, false)
        }
        existing.insert(place, at: 0)
        return (existing, true)
    }

    /// Removes every entry with `placeId` (case-insensitive). Used to roll back a failed add.
    static func revertingAdd(placeId: String, from places: [LightweightPlace]?) -> [LightweightPlace] {
        (places ?? []).filter { !sameId($0.place_id, placeId) }
    }

    /// Re-keys an optimistically inserted entry when the server saved it under a different place id
    /// (the id we had was stale and was resolved by google_places_id). Drops the old entry if the
    /// resolved id is already present so the list never shows the place twice.
    static func replacingPlaceId(_ oldId: String, with newId: String, in places: [LightweightPlace]?) -> [LightweightPlace] {
        guard let places else { return [] }
        if places.contains(where: { sameId($0.place_id, newId) }) {
            return places.filter { !sameId($0.place_id, oldId) }
        }
        return places.map { sameId($0.place_id, oldId) ? $0.withPlaceId(newId) : $0 }
    }

    /// Count to restore after a rolled-back add.
    static func countAfterRollback(previousCount: Int?, currentCount: Int?) -> Int {
        if let previousCount { return previousCount }
        return max((currentCount ?? 0) - 1, 0)
    }

    static func sameId(_ a: String, _ b: String) -> Bool {
        a.caseInsensitiveCompare(b) == .orderedSame
    }
}

extension LightweightPlace {
    /// Copy of this place with a different `place_id`.
    func withPlaceId(_ newId: String) -> LightweightPlace {
        LightweightPlace(
            place_id: newId,
            name: name,
            latitude: latitude,
            longitude: longitude,
            latest_review_photo: latest_review_photo,
            external_place_id: external_place_id,
            content_url: content_url,
            place_type: place_type,
            thumbnail_url: thumbnail_url,
            added_by_user_id: added_by_user_id,
            added_by_name: added_by_name,
            added_by_photo_url: added_by_photo_url
        )
    }
}
