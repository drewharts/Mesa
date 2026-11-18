//
//  ListTypeFilterViewModel.swift
//  loc
//
//  SMART ViewModel: selection state for a list's type chips.
//  Single Responsibility: remembers the selected chip and applies it to the list's places.
//

import Foundation

@MainActor
final class ListTypeFilterViewModel: ObservableObject {
    /// The selected type; nil means "All".
    @Published private(set) var selection: SavedPlaceType?

    /// Chips for the places currently loaded.
    func chips(for places: [LightweightPlace]) -> [ListTypeChip] {
        ListTypeFilter.chips(for: places)
    }

    /// The places to show. A selection whose type is no longer in the list (e.g. after a removal) is ignored.
    func visiblePlaces(from places: [LightweightPlace]) -> [LightweightPlace] {
        guard let selection, chips(for: places).contains(where: { $0.type == selection }) else { return places }
        return ListTypeFilter.apply(selection, to: places)
    }

    /// Selects a chip. Tapping the selected chip again goes back to "All".
    func select(_ chip: ListTypeChip) {
        selection = (chip.type == selection) ? nil : chip.type
    }

    /// Whether a chip is the active one ("All" is active when nothing is selected).
    func isSelected(_ chip: ListTypeChip) -> Bool {
        chip.type == selection
    }
}
