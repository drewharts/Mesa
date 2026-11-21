//
//  ImportAutoSave.swift
//  loc
//
//  Pure rules for saving imported places straight into their city list
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
}
