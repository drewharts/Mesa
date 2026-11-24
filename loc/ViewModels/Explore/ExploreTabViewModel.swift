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

    /// Fetches the public list pool, then publishes cities and the ranked popular lists.
    private func loadLists(userId: String, location: CLLocation?) async {
        guard !isLoadingLists, !hasLoadedLists else { return }
        isLoadingLists = true
        defer {
            isLoadingLists = false
            hasLoadedLists = true
        }
        do {
            let recent = try await service.fetchRecentPublicLists(limit: poolSize)
            pool = recent.filter { $0.ownerId != userId }
            cities = ExploreListRanker.cities(from: pool)
            followedIds = await service.fetchFollowedUserIds(userId: userId)
            await rankPopular(location: location)
            await loadCoverPhotos()
        } catch {
            print("❌ [ExploreTabVM] Failed to load public lists: \(error)")
        }
    }

    // MARK: - Ranking

    /// Re-ranks "Popular near you" when the user has moved meaningfully since the last ranking.
    func updateLocation(_ location: CLLocation?) async {
        guard hasLoadedLists, let location else { return }
        if let rankedLocation, rankedLocation.distance(from: location) < relocationThresholdMeters { return }
        await rankPopular(location: location)
        await loadCoverPhotos()
    }

    /// Picks the top lists near the location (or globally when none are nearby) and attaches owner info.
    private func rankPopular(location: CLLocation?) async {
        rankedLocation = location
        let nearby = location.map { ExploreListRanker.nearby(pool, to: $0) } ?? []
        popularTitle = nearby.isEmpty ? "Popular on Mesa" : "Popular near you"
        let candidates = nearby.isEmpty ? pool : nearby
        popularLists = Array(
            ExploreListRanker.sorted(candidates, by: .popular, followedOwnerIds: followedIds).prefix(popularCount)
        )
        await attachOwners()
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

    /// Returns the place photos to show on a list's card (empty until loaded or when it has none).
    func photos(for list: ExploreList) -> [String] {
        coverPhotos[list.id] ?? []
    }

    /// Returns a background photo for a city, taken from its top-ranked lists that have photos.
    func photoURL(for city: ExploreCity) -> String? {
        cityCoverListIds[city.key]?.lazy.compactMap { self.coverPhotos[$0]?.first }.first
    }

    /// Fetches place photos for the popular lists first, then for each top city's best lists.
    private func loadCoverPhotos() async {
        coverPhotos.merge(await service.fetchCoverPhotos(listIds: popularLists.map(\.id))) { _, new in new }
        cityCoverListIds = ExploreTabViewModel.topListIds(
            for: Array(cities.prefix(coverCityLimit)),
            in: ExploreListRanker.sorted(pool, by: .popular, followedOwnerIds: followedIds),
            perCity: coverListsPerCity
        )
        let ids = cityCoverListIds.values.flatMap { $0 }
        coverPhotos.merge(await service.fetchCoverPhotos(listIds: ids)) { _, new in new }
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
