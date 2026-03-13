//
//  CityDetailViewModel.swift
//  loc
//
//  ViewModel for the city detail sheet showing lists and top places in a city.
//

import CoreLocation
import Foundation
import MapKit
import SwiftUI

/// Navigation destinations available from the city detail sheet.
enum CityDetailDestination: Hashable {
    case allLists
    case allPlaces
    case listDetail(listId: String, listName: String, creatorId: String, creatorName: String?, creatorPhotoUrl: String?)
    case placeDetail(placeId: String)
    case userProfile(userId: String)
}

@MainActor
class CityDetailViewModel: ObservableObject {
    @Published var navigationPath = NavigationPath()
    @Published var lists: [CityDetailListRecord] = []
    @Published var topPlaces: [CityTopPlace] = []
    @Published var activeUsers: [CityActiveUser] = []
    @Published var isLoading: Bool = false
    @Published var listPlaces: [String: [LightweightPlace]] = [:]
    @Published var placeColors: [UUID: Color] = [:]
    @Published var followStates: [String: Bool] = [:]

    // MARK: - Stats (populated from annotation or fetched)

    @Published var placeCount: Int = 0
    @Published var reviewCount: Int = 0
    @Published var friendCount: Int = 0
    @Published var reviewedPlaceCount: Int = 0
    @Published var hasLoadedStats: Bool = false
    @Published private(set) var hasLoadedContent: Bool = false

    private let placeService = ServiceContainer.shared.placeService
    private let userService = ServiceContainer.shared.userService
    private let cityName: String
    private let coordinate: CLLocationCoordinate2D
    private let annotation: CityAnnotation?
    private var currentUserId: String?

    init(cityName: String, coordinate: CLLocationCoordinate2D, annotation: CityAnnotation?) {
        self.cityName = cityName
        self.coordinate = coordinate
        self.annotation = annotation

        if let annotation = annotation {
            populateStats(from: annotation)
        }
    }

    /// Whether all content sections are empty.
    var hasNoContent: Bool {
        lists.isEmpty && topPlaces.isEmpty && activeUsers.isEmpty
    }

    /// Loads lists, top places, active users, and stats (if needed) for the city.
    func loadContent(userId: String) async {
        guard !hasLoadedContent else { return }
        isLoading = true
        currentUserId = userId

        async let listsResult = placeService.fetchCityDetailLists(userId: userId, latitude: coordinate.latitude, longitude: coordinate.longitude)
        async let placesResult = placeService.fetchCityTopPlaces(userId: userId, latitude: coordinate.latitude, longitude: coordinate.longitude)
        async let usersResult = placeService.fetchCityActiveUsers(userId: userId, latitude: coordinate.latitude, longitude: coordinate.longitude)

        do {
            let (fetchedLists, fetchedPlaces, fetchedUsers) = try await (listsResult, placesResult, usersResult)
            self.lists = fetchedLists
            self.topPlaces = fetchedPlaces
            self.activeUsers = fetchedUsers

            await loadPlacesForLists()
            await loadFollowStates()
        } catch {
            print("❌ [CityDetailVM] Error loading city content: \(error.localizedDescription)")
        }

        if !hasLoadedStats {
            await fetchCityStats(userId: userId)
        }

        hasLoadedContent = true
        isLoading = false
    }

    /// Loads follow states for all active users in parallel.
    func loadFollowStates() async {
        guard let currentUserId = currentUserId else { return }

        await withTaskGroup(of: (String, Bool).self) { group in
            for user in activeUsers {
                group.addTask { [userService] in
                    let isFollowing = await withCheckedContinuation { continuation in
                        userService.isFollowingUser(followerId: currentUserId, followingId: user.id) { result in
                            continuation.resume(returning: result)
                        }
                    }
                    return (user.id, isFollowing)
                }
            }
            for await (userId, isFollowing) in group {
                followStates[userId] = isFollowing
            }
        }
    }

    /// Toggles follow state for a user with optimistic UI update, reverting on failure.
    func toggleFollow(userId: String) {
        guard let currentUserId = currentUserId else { return }
        let wasFollowing = followStates[userId] ?? false
        followStates[userId] = !wasFollowing

        if wasFollowing {
            userService.unfollowUser(followerId: currentUserId, followingId: userId) { [weak self] success, _ in
                if !success {
                    Task { @MainActor in self?.followStates[userId] = true }
                }
            }
        } else {
            userService.followUser(followerId: currentUserId, followingId: userId) { [weak self] success, _ in
                if !success {
                    Task { @MainActor in self?.followStates[userId] = false }
                }
            }
        }
    }

    // MARK: - Navigation

    /// Navigates to the full lists grid view.
    func navigateToAllLists() {
        navigationPath.append(CityDetailDestination.allLists)
    }

    /// Navigates to the full popular places grid view.
    func navigateToAllPlaces() {
        navigationPath.append(CityDetailDestination.allPlaces)
    }

    /// Routes a list tap by pushing list detail within the sheet's NavigationStack.
    func handleListTap(_ list: CityDetailListRecord) {
        navigationPath.append(CityDetailDestination.listDetail(
            listId: list.list_id,
            listName: list.name,
            creatorId: list.user_id,
            creatorName: list.creator_name,
            creatorPhotoUrl: list.creator_photo_url
        ))
    }

    /// Routes a place tap by pushing place detail within the sheet's NavigationStack.
    func handlePlaceTap(placeId: String) {
        navigationPath.append(CityDetailDestination.placeDetail(placeId: placeId))
    }

    /// Routes a user tap by pushing user profile within the sheet's NavigationStack.
    func handleUserTap(userId: String, currentUserId: String?) {
        guard userId != currentUserId else { return }
        navigationPath.append(CityDetailDestination.userProfile(userId: userId))
    }

    // MARK: - Private Methods

    /// Fetches the first 3 places for each list to power photo collages.
    private func loadPlacesForLists() async {
        await withTaskGroup(of: (String, [LightweightPlace]).self) { group in
            for list in lists {
                group.addTask { [userService] in
                    let places = (try? await userService.fetchPlacesForPlaceList(
                        listId: list.list_id,
                        page: 1,
                        pageSize: 3
                    )) ?? []
                    return (list.list_id, places)
                }
            }
            for await (listId, places) in group {
                listPlaces[listId] = places
            }
        }
    }

    /// Populates stats directly from a CityAnnotation (map tap path).
    private func populateStats(from annotation: CityAnnotation) {
        placeCount = annotation.placeCount
        reviewCount = annotation.reviewCount
        friendCount = annotation.friendCount
        reviewedPlaceCount = annotation.reviewedPlaceCount
        hasLoadedStats = true
    }

    /// Fetches city stats by querying city annotations in a tight viewport around the coordinate.
    private func fetchCityStats(userId: String) async {
        let delta = 0.15
        do {
            let annotations = try await placeService.fetchCityAnnotationsInViewport(
                northLat: coordinate.latitude + delta,
                southLat: coordinate.latitude - delta,
                eastLng: coordinate.longitude + delta,
                westLng: coordinate.longitude - delta,
                userId: userId
            )
            if let match = annotations.first(where: { $0.name.lowercased() == cityName.lowercased() }) {
                populateStats(from: match)
            } else if let closest = annotations.first {
                populateStats(from: closest)
            }
        } catch {
            print("❌ [CityDetailVM] Error fetching city stats: \(error.localizedDescription)")
        }
    }
}
