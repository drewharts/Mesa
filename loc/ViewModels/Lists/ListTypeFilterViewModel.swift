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

    /// True while the places matching the selected chip that are not loaded yet are being fetched.
    @Published private(set) var isLoadingMatches = false

    /// Tags of EVERY place in the list (not just loaded pages); drives the chips and the filter once fetched.
    @Published private(set) var fullIndex: ListTagIndex?

    private let tagSourceLoader: (String) async -> [LightweightPlace]?
    private let cache: ListTagSourceCache
    private var hasRefreshedSource = false
    private var lastLoadedCount = 0
    private var isFetchingSource = false

    /// Creates the view model; the loader returns tag-only places for a list id (nil on failure).
    init(
        tagSourceLoader: @escaping (String) async -> [LightweightPlace]? = { listId in
            await ListTagSourceLoader.fetch(listId: listId, using: SupabaseManager.shared.client)
        },
        cache: ListTagSourceCache = .shared
    ) {
        self.tagSourceLoader = tagSourceLoader
        self.cache = cache
    }

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
            chips: filtersByType ? (fullIndex?.chips ?? chips(for: places)) : [],
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
        if let fullIndex, fullIndex.contains(tag: selection) {
            let matching = fullIndex.placeIds(tagged: selection)
            return places.filter { matching.contains($0.place_id.lowercased()) }
        }
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

    /// Ids (lowercased) of places in the whole list that match the selected chip but are not in `loaded`.
    func unloadedMatchIds(loaded: [LightweightPlace]) -> Set<String> {
        guard let selection, let fullIndex else { return [] }
        return fullIndex.placeIds(tagged: selection).subtracting(loaded.map { $0.place_id.lowercased() })
    }

    /// Loads the rest of the list when the selected chip matches places that are not loaded yet, so the chip
    /// shows ALL its places. `loaded` reads the current places; `loadAll` fetches the remaining pages.
    func loadMatchesIfNeeded(loaded: () -> [LightweightPlace], loadAll: () async -> Void) async {
        let chosen = selection
        guard chosen != nil, !unloadedMatchIds(loaded: loaded()).isEmpty else { return }
        isLoadingMatches = true
        await loadAll()
        // A newer selection owns the spinner now.
        if selection == chosen { isLoadingMatches = false }
    }

    /// Fetches the whole-list tag source when it is missing, stale (places were added or removed) or not yet
    /// refreshed this session; a cached copy is used immediately in the meantime.
    func refreshTagSource(listId: String, loaded: [LightweightPlace]) async {
        if fullIndex == nil, let cached = cache.index(for: listId) { setFullIndex(cached) }
        let hasUnknownPlace = fullIndex.map { (index: ListTagIndex) -> Bool in
            let known = Set(index.tagsByPlaceId.keys.map { $0.lowercased() })
            return loaded.contains { !known.contains($0.place_id.lowercased()) }
        } ?? false
        let shrank = loaded.count < lastLoadedCount
        lastLoadedCount = loaded.count
        guard !isFetchingSource, !hasRefreshedSource || hasUnknownPlace || shrank || fullIndex == nil else { return }
        isFetchingSource = true
        defer { isFetchingSource = false }
        guard let source = await tagSourceLoader(listId) else { return }
        hasRefreshedSource = true
        let index = ListTypeFilter.index(for: source)
        cache.store(index, for: listId)
        setFullIndex(index)
    }

    /// Publishes a new whole-list index and drops the memoized display so chips and tiles recompute.
    private func setFullIndex(_ index: ListTagIndex) {
        cachedDisplay = nil
        fullIndex = index
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
