//
//  ListTypeFilterViewModel.swift
//  loc
//
//  SMART ViewModel: selection state for a list's tag chips.
//  Single Responsibility: remembers the selected tag, caches the tag index per load, and applies the selection.
//

import Foundation

@MainActor
final class ListTypeFilterViewModel: ObservableObject {
    /// The selected tag; nil means "All".
    @Published private(set) var selection: String?

    /// Tag index for the last places seen. Not published: it is a memo, rebuilt only when the places change.
    private var cachedSignature: Int?
    private var cachedIndex = ListTagIndex.empty

    /// Everything the list needs to render one frame, computed together so the view asks once per render.
    struct Display {
        let chips: [ListTypeChip]
        let tiles: [LightweightPlace]
        /// Ids (lowercased) of the last few tiles; appearing one of them asks for the next page.
        let loadMoreTriggerIds: Set<String>
    }

    /// Number of trailing tiles whose appearance triggers loading the next page.
    private static let loadMoreLookahead = 3

    private var cachedDisplay: (places: [LightweightPlace], selection: String?, filtersByType: Bool, display: Display)?

    /// The chips and de-duplicated, filtered tiles for the places. Memoized on the exact places and selection
    /// (full equality, since tiles render most fields), so re-renders during scrolling (hours, neighborhoods,
    /// focus) do not re-filter hundreds of places.
    func display(for places: [LightweightPlace], filtersByType: Bool) -> Display {
        if let hit = cachedDisplay, hit.filtersByType == filtersByType, hit.selection == selection, hit.places == places {
            return hit.display
        }
        let shown = filtersByType ? visiblePlaces(from: places) : places
        let tiles = ListTypeFilter.uniquePlaces(shown)
        let display = Display(
            chips: filtersByType ? chips(for: places) : [],
            tiles: tiles,
            loadMoreTriggerIds: Set(tiles.suffix(Self.loadMoreLookahead).map { $0.place_id.lowercased() })
        )
        cachedDisplay = (places, selection, filtersByType, display)
        return display
    }

    /// Chips for the places currently loaded.
    func chips(for places: [LightweightPlace]) -> [ListTypeChip] {
        index(for: places).chips
    }

    /// The places to show. A selected tag no list place carries any more (e.g. after a removal) is ignored.
    func visiblePlaces(from places: [LightweightPlace]) -> [LightweightPlace] {
        guard let selection else { return places }
        let index = index(for: places)
        guard index.contains(tag: selection) else { return places }
        return index.places(tagged: selection, in: places)
    }

    /// Selects a chip. Tapping the selected chip again goes back to "All".
    func select(_ chip: ListTypeChip) {
        selection = (chip.tag == selection) ? nil : chip.tag
    }

    /// Whether a chip is the active one ("All" is active when nothing is selected).
    func isSelected(_ chip: ListTypeChip) -> Bool {
        chip.tag == selection
    }

    /// Returns the cached tag index, recomputing it only when the places' ids, categories or names changed.
    private func index(for places: [LightweightPlace]) -> ListTagIndex {
        let signature = Self.signature(of: places)
        if signature != cachedSignature {
            cachedIndex = ListTypeFilter.index(for: places)
            cachedSignature = signature
        }
        return cachedIndex
    }

    /// Hashes the fields the tags depend on, so renders with unchanged places reuse the cached index.
    private static func signature(of places: [LightweightPlace]) -> Int {
        var hasher = Hasher()
        for place in places {
            hasher.combine(place.place_id)
            hasher.combine(place.place_type)
            hasher.combine(place.categories)
            hasher.combine(place.user_corrected_category)
            hasher.combine(place.name)
        }
        return hasher.finalize()
    }
}
