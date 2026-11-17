//
//  ImportAutoSave.swift
//  loc
//
//  Pure rules for saving imported places straight into the auto-sorted Saved library
//  (same default as the one-tap bookmark), instead of forcing the list picker.
//

import Foundation

enum ImportAutoSave {
    /// Returns the places that still need saving: resolved ids only, minus ones already auto-saved.
    static func placesToSave(from places: [DetailPlace], alreadySaved: Set<String>) -> [DetailPlace] {
        places.filter {
            let id = $0.id.uuidString
            return !PlaceIdGuard.isPlaceholder(id) && !alreadySaved.contains(id)
        }
    }

    /// Builds the banner text: "Saved to {City · Type}" for one place, "Saved N places" for several.
    static func bannerMessage(for places: [DetailPlace]) -> String? {
        guard let first = places.first else { return nil }
        guard places.count == 1 else { return "Saved \(places.count) places" }
        let placement = SavedQuickSave.placementLabel(
            name: first.name, storedCity: first.city, address: first.address,
            categories: first.categories ?? [], corrected: first.userCorrectedCategory
        )
        return "Saved to \(placement)"
    }
}
