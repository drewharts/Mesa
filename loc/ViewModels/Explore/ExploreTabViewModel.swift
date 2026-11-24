//
//  ExploreTabViewModel.swift
//  loc
//
//  Parent ViewModel for the Explore tab. Loads one pool of recent public lists and derives
//  "Popular near you" and "Browse by city" from it; people suggestions live in a child ViewModel.
//

import Foundation
import CoreLocation

@MainActor
final class ExploreTabViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var popularLists: [ExploreList] = []
    @Published private(set) var popularTitle = "Popular near you"
    @Published private(set) var cities: [ExploreCity] = []
    @Published private(set) var coverPhotos: [String: [String]] = [:]
    /// Featured lists that finished loading, keyed by lowercased list id.
    @Published private(set) var featuredLists: [String: ExploreList] = [:]
    @Published private(set) var isLoadingLists = false
    @Published private(set) var hasLoadedLists = false

    // MARK: - Child ViewModels

    let peopleViewModel = ExplorePeopleViewModel()

    // MARK: - Private State

    private let service = ExploreListsService.shared
    private let poolSize = 1000
    private let popularCount = 12
    private let coverCityLimit = 20
    private let coverListsPerCity = 2
    private let relocationThresholdMeters: CLLocationDistance = 5_000
    private var pool: [ExploreList] = []
    private var followedIds: Set<String> = []
    private var ownerCache: [String: ExploreListOwner] = [:]
    private var rankedLocation: CLLocation?
    private var cityCoverListIds: [String: [String]] = [:]

    /// True once lists finished loading and nothing public was found.
    var hasNoLists: Bool { hasLoadedLists && popularLists.isEmpty && cities.isEmpty }

    // MARK: - Loading

    /// Loads lists, cities, and people suggestions; each section publishes as soon as it is ready.
    func load(userId: String, location: CLLocation?) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.primeFromDisk() }
            group.addTask { await self.loadFeatured() }
            group.addTask { await self.loadLists(userId: userId, location: location) }
            group.addTask { await self.peopleViewModel.load(userId: userId) }
        }
    }

    /// Reloads everything, bypassing the "already loaded" guards (pull to refresh).
    func refresh(userId: String, location: CLLocation?) async {
        hasLoadedLists = false
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadLists(userId: userId, location: location) }
            group.addTask { await self.peopleViewModel.load(userId: userId, force: true) }
        }
    }

    /// Fetches the public list pool and the user's follows in parallel, then publishes cities and popular lists.
    private func loadLists(userId: String, location: CLLocation?) async {
        guard !isLoadingLists, !hasLoadedLists else { return }
        isLoadingLists = true
        defer {
            isLoadingLists = false
            hasLoadedLists = true
        }
        do {
            async let recentTask = service.fetchRecentPublicLists(limit: poolSize)
            async let followedTask = service.fetchFollowedUserIds(userId: userId)
            let recent = try await recentTask
            followedIds = await followedTask
            pool = recent.filter { $0.ownerId != userId }
            cities = ExploreListRanker.cities(from: pool)
            applyRanking(location: location)
            await attachOwnersAndLoadCovers()
        } catch {
            print("❌ [ExploreTabVM] Failed to load public lists: \(error)")
        }
    }

    /// Looks up popular-list owners and cover photos at the same time (neither waits for the other).
    private func attachOwnersAndLoadCovers() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.attachOwners() }
            group.addTask { await self.loadCoverPhotos() }
        }
        persistCovers()
    }

    // MARK: - Ranking

    /// Re-ranks "Popular near you" when the user has moved meaningfully since the last ranking.
    func updateLocation(_ location: CLLocation?) async {
        guard hasLoadedLists, let location else { return }
        if let rankedLocation, rankedLocation.distance(from: location) < relocationThresholdMeters { return }
        applyRanking(location: location)
        await attachOwnersAndLoadCovers()
    }

    /// Picks the top lists near the location (or globally when none are nearby) and publishes them.
    private func applyRanking(location: CLLocation?) {
        rankedLocation = location
        let nearby = location.map { ExploreListRanker.nearby(pool, to: $0) } ?? []
        popularTitle = nearby.isEmpty ? "Popular on Mesa" : "Popular near you"
        let candidates = nearby.isEmpty ? pool : nearby
        popularLists = Array(
            ExploreListRanker.sorted(candidates, by: .popular, followedOwnerIds: followedIds).prefix(popularCount)
        )
    }

    /// Fills in owner names and photos for the popular lists with one batched lookup.
    private func attachOwners() async {
        let missing = Set(popularLists.map(\.ownerId)).subtracting(ownerCache.keys)
        if !missing.isEmpty {
            let fetched = await service.fetchOwners(ids: Array(missing))
            ownerCache.merge(fetched) { existing, _ in existing }
        }
        popularLists = popularLists.map { list in
            var updated = list
            updated.ownerName = ownerCache[list.ownerId]?.name
            updated.ownerPhotoURL = ownerCache[list.ownerId]?.photoURL
            return updated
        }
    }

    // MARK: - Cover Photos

    /// Returns the place photos for a list id (empty until loaded).
    func photos(forListId id: String) -> [String] {
        coverPhotos[id] ?? []
    }

    /// Returns the place photos to show on a list's card (empty until loaded or when it has none).
    func photos(for list: ExploreList) -> [String] {
        coverPhotos[list.id] ?? []
    }

    /// Returns a background photo for a city, taken from its top-ranked lists that have photos.
    func photoURL(for city: ExploreCity) -> String? {
        cityCoverListIds[city.key]?.lazy.compactMap { self.coverPhotos[$0]?.first }.first
    }

    /// Fetches place photos for the popular lists and for each top city's best lists, both at once.
    private func loadCoverPhotos() async {
        cityCoverListIds = ExploreTabViewModel.topListIds(
            for: Array(cities.prefix(coverCityLimit)),
            in: ExploreListRanker.sorted(pool, by: .popular, followedOwnerIds: followedIds),
            perCity: coverListsPerCity
        )
        let popularIds = popularLists.map(\.id)
        let cityIds = cityCoverListIds.values.flatMap { $0 }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadCovers(for: popularIds, frame: ExploreCoverMetrics.card) }
            group.addTask { await self.loadCovers(for: cityIds, frame: ExploreCoverMetrics.city) }
        }
    }

    /// Fetches covers for the lists, publishes them, and warms their images at the size the cards will draw.
    private func loadCovers(for ids: [String], frame: CGSize) async {
        let fetched = await service.fetchCoverPhotos(listIds: ids)
        coverPhotos.merge(fetched) { _, new in new }
        prefetchImages(for: ids, frame: frame)
    }

    /// Warms the image cache for each list's visible collage photos at the given frame size.
    private func prefetchImages(for ids: [String], frame: CGSize) {
        for id in ids {
            let urls = PlacePhotoCollageLayout.visibleURLs(coverPhotos[id] ?? [], failed: [])
            let size = PlacePhotoCollageLayout.cellSize(forPhotoCount: urls.count, frame: frame)
            ImageCacheService.shared.prefetch(urls: urls.compactMap { URL(string: $0) }, targetSize: size)
        }
    }

    /// Saves covers and their on-screen order so the next launch can paint and prefetch them immediately.
    private func persistCovers() {
        let order = FeaturedLists.all.map(\.listId) + popularLists.map(\.id) + cityCoverListIds.values.flatMap { $0 }
        service.persistCovers(displayOrder: order)
    }

    /// Shows the previous session's covers right away and warms their images before any network call returns.
    private func primeFromDisk() async {
        let snapshot = await Task.detached { CoverPhotoStore.shared.load() }.value
        for (id, photos) in snapshot.covers where coverPhotos[id] == nil { coverPhotos[id] = photos }
        let featuredIds = Set(FeaturedLists.all.map(\.listId))
        prefetchImages(for: Array(featuredIds), frame: ExploreCoverMetrics.hero)
        let others = snapshot.displayOrder.filter { !featuredIds.contains($0) }
        prefetchImages(for: Array(others.prefix(popularCount)), frame: ExploreCoverMetrics.card)
    }

    // MARK: - Featured

    /// Loads the featured lists, their owners and covers; independent of the rest of the page.
    private func loadFeatured() async {
        let ids = FeaturedLists.all.map(\.listId)
        async let coversTask: Void = loadCovers(for: ids, frame: ExploreCoverMetrics.hero)
        let lists = await service.fetchLists(ids: ids)
        let owners = await service.fetchOwners(ids: Array(Set(lists.map(\.ownerId))))
        for var list in lists {
            list.ownerName = owners[list.ownerId]?.name
            list.ownerPhotoURL = owners[list.ownerId]?.photoURL
            featuredLists[list.id.lowercased()] = list
        }
        await coversTask
    }

    /// Resolves the featured list (fetching it if needed) and hands it to `open`; does nothing if it can't be loaded.
    func openFeatured(_ config: FeaturedListConfig, using open: (ExploreList) -> Void) async {
        guard let list = await featuredList(for: config) else { return }
        open(list)
    }

    /// Returns the featured list for a config, fetching it on demand if the page load has not finished.
    func featuredList(for config: FeaturedListConfig) async -> ExploreList? {
        if let loaded = featuredLists[config.listId] { return loaded }
        await loadFeatured()
        return featuredLists[config.listId]
    }

    /// Maps each city key to its first `perCity` lists from a popularity-sorted list array.
    private static func topListIds(for cities: [ExploreCity], in sortedLists: [ExploreList], perCity: Int) -> [String: [String]] {
        let wanted = Set(cities.map(\.key))
        var result: [String: [String]] = [:]
        for list in sortedLists {
            guard let city = list.city?.trimmingCharacters(in: .whitespacesAndNewlines), !city.isEmpty else { continue }
            let key = CityListMatcher.cityKey(city)
            guard wanted.contains(key), (result[key]?.count ?? 0) < perCity else { continue }
            result[key, default: []].append(list.id)
        }
        return result
    }
}
