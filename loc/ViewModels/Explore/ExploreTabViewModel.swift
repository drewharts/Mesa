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
    @Published private(set) var isLoadingLists = false
    @Published private(set) var hasLoadedLists = false

    // MARK: - Child ViewModels

    let peopleViewModel = ExplorePeopleViewModel()

    // MARK: - Private State

    private let service = ExploreListsService.shared
    private let poolSize = 1000
    private let popularCount = 12
    private let relocationThresholdMeters: CLLocationDistance = 5_000
    private var pool: [ExploreList] = []
    private var followedIds: Set<String> = []
    private var ownerCache: [String: ExploreListOwner] = [:]
    private var rankedLocation: CLLocation?

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
}
