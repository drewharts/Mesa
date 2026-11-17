//
//  SavedCityDetailViewModel.swift
//  loc
//
//  Drives one city's list (or one smart group): the chip row at the top (All, types, cuisines),
//  the selected chip, and the places it keeps, nearest first when location is on.
//

import Foundation

@MainActor
final class SavedCityDetailViewModel: ObservableObject {
    enum Ordering { case nearest, recent }

    let title: String
    /// Smart groups mix cities, so their rows say which city each place is in.
    let showsCity: Bool
    let chips: [CityFilterChip]
    @Published var selected: CityFilterChip.Kind = .all

    private let orderedPlaces: [SavedLibraryPlace]

    /// Orders the places once (nearest first or newest first) and builds the chip row.
    init(title: String, places: [SavedLibraryPlace], ordering: Ordering, showsCity: Bool) {
        self.title = title
        self.showsCity = showsCity
        self.orderedPlaces = CityListFilter.sorted(places, byDistance: ordering == .nearest)
        self.chips = CityListFilter.chips(for: places)
    }

    /// Places the selected chip keeps, in display order.
    var visiblePlaces: [SavedLibraryPlace] {
        CityListFilter.apply(selected, to: orderedPlaces)
    }

    /// Selects a chip; tapping the selected cuisine / type chip again goes back to All.
    func select(_ kind: CityFilterChip.Kind) {
        selected = (selected == kind) ? .all : kind
    }

    /// "Japanese · Brooklyn · 1.2 mi". The type shows under All; a cuisine chip hides the repeated cuisine.
    func subtitle(for place: SavedLibraryPlace) -> String {
        var parts: [String] = []
        if let cuisine = place.cuisine {
            if selected != .cuisine(cuisine) { parts.append(cuisine) }
        } else if selected == .all {
            parts.append(place.type.title)
        }
        if showsCity { parts.append(place.area ?? place.city) } else if let area = place.area { parts.append(area) }
        if let meters = place.distanceMeters {
            parts.append(TonightRanker.formatDistance(meters, metric: Locale.current.measurementSystem != .us))
        }
        return parts.joined(separator: " · ")
    }
}
