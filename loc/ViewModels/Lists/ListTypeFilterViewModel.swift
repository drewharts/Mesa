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

    /// True when the selected chip still has places that could not be loaded (network failure); drives a retry state.
    @Published private(set) var matchesLoadFailed = false

    /// True while the chip row's search field is expanded.
    @Published private(set) var isSearching = false

    /// The raw text typed in the search field; blank means no search is applied.
    @Published private(set) var searchQuery = ""

    /// Loads attempted per selection before reporting failure.
    private static let maxLoadAttempts = 2
    /// Most skeleton tiles shown for pending matches.
    private static let maxSkeletonTiles = 4
    /// Most tiles whose images are warmed per selection change.
    private static let prefetchLimit = 24

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
        /// The chips to show: all of them, or only the tags matching the search query.
        let chips: [ListTypeChip]
        /// Whether the chip row (and its search button) is shown at all; stays true while a search matches no tag.
        let showsFilterRow: Bool
        let tiles: [LightweightPlace]
        /// Ids (lowercased) of the last few tiles; appearing one of them asks for the next page.
        let loadMoreTriggerIds: Set<String>
        /// Ids (lowercased) of every place in the selected chip (loaded or not); nil on "All".
        let scopeIds: Set<String>?
    }

    /// Number of trailing tiles whose appearance triggers loading the next page.
    private static let loadMoreLookahead = 3

    private var cachedDisplay: (places: [LightweightPlace], selection: String?, query: String, filtersByType: Bool, display: Display)?
    private var searchCache: (key: String, result: ListTagSearch.Result?)?

    /// What the list is currently narrowed by; used to notice that a newer selection or query took over.
    private struct Scope: Equatable {
        let selection: String?
        let query: String
    }

    private var scope: Scope { Scope(selection: selection, query: ListTagSearch.normalize(searchQuery)) }

    /// The chips and de-duplicated, filtered tiles for the places. Memoized on the exact places and selection
    /// (full equality, since tiles render most fields), so re-renders during scrolling (hours, neighborhoods,
    /// focus) do not re-filter hundreds of places.
    func display(for places: [LightweightPlace], filtersByType: Bool) -> Display {
        if let hit = cachedDisplay, hit.filtersByType == filtersByType, hit.selection == selection,
           hit.query == searchQuery, hit.places == places {
            return hit.display
        }
        let shown = filtersByType ? visiblePlaces(from: places) : places
        let tiles = ListTypeFilter.uniquePlaces(shown)
        let baseChips = filtersByType ? chipsWithSelection(fullIndex?.chips ?? chips(for: places)) : []
        let display = Display(
            chips: filtersByType ? (currentSearch(loaded: places).map { searchChips($0.tags) } ?? baseChips) : [],
            showsFilterRow: !baseChips.isEmpty,
            tiles: tiles,
            loadMoreTriggerIds: Set(tiles.suffix(Self.loadMoreLookahead).map { $0.place_id.lowercased() }),
            scopeIds: filtersByType ? scopeIds(loaded: shown) : nil
        )
        cachedDisplay = (places, selection, searchQuery, filtersByType, display)
        return display
    }

    /// Every place the search or the selected chip keeps: the whole list's matches once the full index is known
    /// (so the count and map cover unloaded pages too), else the loaded matches. nil on "All".
    private func scopeIds(loaded shown: [LightweightPlace]) -> Set<String>? {
        if let search = currentSearch(loaded: shown) { return search.placeIds }
        guard let selection else { return nil }
        if let fullIndex, fullIndex.contains(tag: selection) { return fullIndex.placeIds(tagged: selection) }
        return Set(shown.map { $0.place_id.lowercased() })
    }

    /// How many placeholder tiles to show for matches that are still loading (capped so the grid stays calm).
    func pendingSkeletonCount(loaded: [LightweightPlace]) -> Int {
        guard isLoadingMatches else { return 0 }
        return min(max(unloadedMatchIds(loaded: loaded).count, 1), Self.maxSkeletonTiles)
    }

    /// Whether loading more pages could still reveal matches: always true until the whole-list index is known.
    func mayHaveUnloadedMatches(loaded: [LightweightPlace]) -> Bool {
        guard hasActiveScope else { return true }
        return fullIndex == nil || !unloadedMatchIds(loaded: loaded).isEmpty
    }

    /// Width of one grid tile: two columns inside 16pt side padding with a 12pt gap (rounded down like the cache key).
    static func gridTileSide(screenWidth: CGFloat) -> CGFloat {
        ((screenWidth - 32 - 12) / 2).rounded(.down)
    }

    /// Warms the image cache (downsampled to the tile size) for the first tiles that are not already in memory.
    func prefetchImages(for tiles: [LightweightPlace], tileSide: CGFloat) {
        let urls = tiles.prefix(Self.prefetchLimit).compactMap { ListTilePhoto.url(for: $0) }
        ImageCacheService.shared.prefetch(urls: urls, targetSize: CGSize(width: tileSide, height: tileSide))
    }

    /// Chips for the places currently loaded.
    func chips(for places: [LightweightPlace]) -> [ListTypeChip] {
        index(for: places).chips
    }

    /// The places to show. A selected tag no list place carries any more (e.g. after a removal) is ignored.
    func visiblePlaces(from places: [LightweightPlace]) -> [LightweightPlace] {
        if let search = currentSearch(loaded: places) {
            return places.filter { search.placeIds.contains($0.place_id.lowercased()) }
        }
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
        matchesLoadFailed = false
    }

    /// Marks matches as loading straight away when the new selection has unloaded places, so the list shows a
    /// loading state instead of a flash of the empty state before the load task starts.
    func beginLoadingMatchesIfNeeded(loaded: [LightweightPlace]) {
        isLoadingMatches = hasActiveScope && !unloadedMatchIds(loaded: loaded).isEmpty
    }

    /// Whether a chip is the active one ("All" is active when nothing is selected). While a query narrows the
    /// list the selection is set aside, so no chip is highlighted.
    func isSelected(_ chip: ListTypeChip) -> Bool {
        !hasSearchQuery && chip.tag == selection
    }

    /// Ids (lowercased) of places in the whole list that match the selected chip but are not in `loaded`.
    func unloadedMatchIds(loaded: [LightweightPlace]) -> Set<String> {
        guard let fullIndex, let ids = wholeListIds(in: fullIndex) else { return [] }
        return ids.subtracting(loaded.map { $0.place_id.lowercased() })
    }

    /// Loads the rest of the list when the selected chip matches places that are not loaded yet, so the chip
    /// shows ALL its places. `loaded` reads the current places; `loadAll` fetches the remaining pages and is
    /// retried once when matches are still missing afterwards.
    func loadMatchesIfNeeded(loaded: () -> [LightweightPlace], loadAll: () async -> Void) async {
        let chosen = scope
        guard hasActiveScope, !unloadedMatchIds(loaded: loaded()).isEmpty else {
            isLoadingMatches = false
            return
        }
        isLoadingMatches = true
        matchesLoadFailed = false
        var attempts = 0
        while attempts < Self.maxLoadAttempts, scope == chosen, !unloadedMatchIds(loaded: loaded()).isEmpty {
            await loadAll()
            attempts += 1
        }
        // A newer selection or query owns the spinner now.
        guard scope == chosen else { return }
        matchesLoadFailed = !unloadedMatchIds(loaded: loaded()).isEmpty
        isLoadingMatches = false
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
        searchCache = nil
        fullIndex = index
    }

    // MARK: - Search

    /// Whether a non-blank query is narrowing the list.
    var hasSearchQuery: Bool { !ListTagSearch.normalize(searchQuery).isEmpty }

    /// Whether the list is narrowed by a query or a selected chip.
    private var hasActiveScope: Bool { selection != nil || hasSearchQuery }

    /// Expands the search field.
    func beginSearch() {
        isSearching = true
    }

    /// Updates the typed query; the list, map scope and chips follow immediately (all client-side).
    func setSearchQuery(_ text: String) {
        searchQuery = text
    }

    /// Collapses the search field and clears the query, returning to the selected chip (or "All").
    func endSearch() {
        searchQuery = ""
        isSearching = false
        matchesLoadFailed = false
    }

    /// The (x) button: clears typed text first, and collapses the field when there is nothing left to clear.
    func clearOrCloseSearch() {
        if searchQuery.isEmpty { endSearch() } else { searchQuery = "" }
    }

    /// Handles a chip tap: while searching it applies that chip and collapses the field; otherwise it toggles as usual.
    func handleChipTap(_ chip: ListTypeChip) {
        guard isSearching else { return select(chip) }
        selection = chip.tag
        endSearch()
    }

    /// The search result for the current query over the whole-list index (or the loaded places until it arrives);
    /// nil without a query. Memoized so renders and load checks do not re-run the search.
    private func currentSearch(loaded: [LightweightPlace]) -> ListTagSearch.Result? {
        guard hasSearchQuery else { return nil }
        if let fullIndex { return searchResult(in: fullIndex, source: "full") }
        let loadedIndex = index(for: loaded)
        return searchResult(in: loadedIndex, source: "loaded\(cachedSignature ?? 0)")
    }

    /// Runs the current query over an index, reusing the last result for the same query and index source.
    private func searchResult(in index: ListTagIndex, source: String) -> ListTagSearch.Result? {
        let key = ListTagSearch.normalize(searchQuery) + "|" + source
        if let cached = searchCache, cached.key == key { return cached.result }
        let result = ListTagSearch.search(searchQuery, in: index)
        searchCache = (key, result)
        return result
    }

    /// Ids (lowercased) of every place the query or the selected chip keeps in the whole list; nil when neither applies.
    private func wholeListIds(in fullIndex: ListTagIndex) -> Set<String>? {
        if hasSearchQuery { return searchResult(in: fullIndex, source: "full")?.placeIds }
        return selection.map { fullIndex.placeIds(tagged: $0) }
    }

    /// Chips for search results: one per matching tag, in rank order.
    private func searchChips(_ tags: [String]) -> [ListTypeChip] {
        tags.map { ListTypeChip(tag: $0, title: $0) }
    }

    /// The chips with the selected tag added after "All" when it is a rare tag the row omits, so a chip picked
    /// from search stays visible and selected once the field collapses.
    private func chipsWithSelection(_ chips: [ListTypeChip]) -> [ListTypeChip] {
        guard let selection, !chips.isEmpty, !chips.contains(where: { $0.tag == selection }),
              fullIndex?.contains(tag: selection) == true else { return chips }
        var result = chips
        result.insert(ListTypeChip(tag: selection, title: selection), at: min(1, result.count))
        return result
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
