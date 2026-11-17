//
//  CityListFilter.swift
//  loc
//
//  Pure rules for the single per-city list: which filter chips a city offers
//  (All, types present, cuisines for restaurants), what each chip keeps, and how places are ordered.
//  Unit tested in CityListFilterTests.
//

import Foundation

/// One chip in the horizontally scrolling row at the top of a city.
struct CityFilterChip: Hashable, Identifiable {
    enum Kind: Hashable {
        case all
        case type(SavedPlaceType)
        case cuisine(String)
    }

    var kind: Kind
    var title: String
    var count: Int

    var id: Kind { kind }
}

enum CityListFilter {
    /// Most cuisine chips shown, so the row never turns into a wall of one-off cuisines.
    static let maxCuisineChips = 12

    /// All, then each type present (in the fixed type order), then the cuisines found on restaurants (most common first).
    static func chips(for places: [SavedLibraryPlace]) -> [CityFilterChip] {
        var chips = [CityFilterChip(kind: .all, title: "All", count: places.count)]
        for type in SavedPlaceType.allCases {
            let count = places.filter { $0.type == type }.count
            if count > 0 { chips.append(CityFilterChip(kind: .type(type), title: type.title, count: count)) }
        }
        for (cuisine, count) in cuisineCounts(in: places).prefix(maxCuisineChips) {
            chips.append(CityFilterChip(kind: .cuisine(cuisine), title: cuisine, count: count))
        }
        return chips
    }

    /// Restaurant cuisines with their place counts, most common first, then A-Z.
    static func cuisineCounts(in places: [SavedLibraryPlace]) -> [(cuisine: String, count: Int)] {
        var counts: [String: Int] = [:]
        for place in places where place.type == .restaurants {
            if let cuisine = place.cuisine { counts[cuisine, default: 0] += 1 }
        }
        return counts.map { (cuisine: $0.key, count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.cuisine < $1.cuisine }
    }

    /// The places a chip keeps. `.all` keeps everything.
    static func apply(_ kind: CityFilterChip.Kind, to places: [SavedLibraryPlace]) -> [SavedLibraryPlace] {
        switch kind {
        case .all: return places
        case .type(let type): return places.filter { $0.type == type }
        case .cuisine(let cuisine): return places.filter { $0.type == .restaurants && $0.cuisine == cuisine }
        }
    }

    /// Nearest first when any place has a distance (places without one go last), else newest-added first.
    static func sorted(_ places: [SavedLibraryPlace], byDistance: Bool) -> [SavedLibraryPlace] {
        guard byDistance, places.contains(where: { $0.distanceMeters != nil }) else {
            return SavedLibraryBuilder.sortPlaces(places)
        }
        return places.sorted { a, b in
            switch (a.distanceMeters, b.distanceMeters) {
            case let (x?, y?) where x != y: return x < y
            case (_?, nil): return true
            case (nil, _?): return false
            default: return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
        }
    }
}
