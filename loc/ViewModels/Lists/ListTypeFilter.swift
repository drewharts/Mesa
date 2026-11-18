//
//  ListTypeFilter.swift
//  loc
//
//  Pure rules for the type chips inside a list (All, Restaurants, Bars, Coffee & Sweets, Shops, Sights,
//  Stays, Other): which chips a list offers and which places each keeps. Reuses the Saved classifier
//  so a place lands under the same type everywhere. Unit tested in ListTypeFilterTests.
//

import Foundation

/// One chip in a list's horizontally scrolling filter row. `type == nil` is "All".
struct ListTypeChip: Hashable, Identifiable {
    let type: SavedPlaceType?
    let title: String

    var id: String { type?.rawValue ?? "all" }
}

enum ListTypeFilter {
    /// Fewest distinct types a list needs before the chip row is worth showing.
    static let minTypesForChips = 2

    /// The type a list place is filed under, from its primary category and name.
    static func type(of place: LightweightPlace) -> SavedPlaceType {
        SavedLibraryBuilder.classify(categories: [place.place_type].compactMap { $0 }, corrected: nil, name: place.name)
    }

    /// "All" followed by each type present, in the fixed type order. Empty when the list has too few types to filter.
    static func chips(for places: [LightweightPlace]) -> [ListTypeChip] {
        let present = Set(places.map(type(of:)))
        guard present.count >= minTypesForChips else { return [] }
        let typeChips = SavedPlaceType.allCases.filter(present.contains).map { ListTypeChip(type: $0, title: $0.title) }
        return [ListTypeChip(type: nil, title: "All")] + typeChips
    }

    /// The places a selection keeps; nil ("All") keeps everything.
    static func apply(_ selection: SavedPlaceType?, to places: [LightweightPlace]) -> [LightweightPlace] {
        guard let selection else { return places }
        return places.filter { type(of: $0) == selection }
    }
}
