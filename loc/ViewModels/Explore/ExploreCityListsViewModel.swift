//
//  ExploreCityListsViewModel.swift
//  loc
//
//  ViewModel for a single city's public lists, sortable by Popular / Newest / Most places.
//

import Foundation

@MainActor
final class ExploreCityListsViewModel: ObservableObject {

    // MARK: - Published State

    @Published var sort: ExploreListSort = .popular
    @Published private(set) var lists: [ExploreList] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false

    // MARK: - Properties

    let city: ExploreCity
    private let service = ExploreListsService.shared
    private let maxLists = 200
    private var followedIds: Set<String> = []

    /// The city's lists in the selected sort order.
    var sortedLists: [ExploreList] {
        ExploreListRanker.sorted(lists, by: sort, followedOwnerIds: followedIds)
    }

    // MARK: - Initialization

    /// Creates the ViewModel for one city.
    init(city: ExploreCity) {
        self.city = city
    }

    // MARK: - Loading

    /// Loads the city's public lists, then follow state and owner info so ranking and names refine in place.
    func load(userId: String?) async {
        guard !isLoading, !hasLoaded else { return }
        isLoading = true
        defer {
            isLoading = false
            hasLoaded = true
        }
        do {
            let fetched = try await service.fetchPublicLists(inCities: city.rawNames, limit: maxLists)
            lists = fetched.filter { $0.ownerId != userId }
        } catch {
            print("❌ [ExploreCityListsVM] Failed to load lists for \(city.name): \(error)")
            return
        }
        if let userId {
            followedIds = await service.fetchFollowedUserIds(userId: userId)
        }
        await attachOwners()
    }

    /// Fills in owner names and photos for every list with one batched lookup.
    private func attachOwners() async {
        let owners = await service.fetchOwners(ids: Array(Set(lists.map(\.ownerId))))
        lists = lists.map { list in
            var updated = list
            updated.ownerName = owners[list.ownerId]?.name
            updated.ownerPhotoURL = owners[list.ownerId]?.photoURL
            return updated
        }
    }
}
