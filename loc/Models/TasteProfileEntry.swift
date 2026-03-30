//
//  TasteProfileEntry.swift
//  loc
//
//  A single category entry in the user's taste profile.
//

import Foundation

struct TasteProfileEntry: Identifiable, Codable {
    let placeType: String
    let count: Int

    var id: String { placeType }

    /// Translated display name for the raw place type.
    var displayName: String {
        PlaceTypeTranslator.translate(placeType)
    }

    /// Emoji for this place type.
    var emoji: String {
        PlaceTypeEmoji.emoji(for: placeType)
    }

    enum CodingKeys: String, CodingKey {
        case placeType = "place_type"
        case count
    }
}
