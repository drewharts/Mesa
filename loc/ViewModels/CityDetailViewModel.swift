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
    case allVideos
    case allPhotos
    case placeDetail(placeId: String)
    case listDetail(listId: String, listName: String, creatorId: String, creatorName: String?, creatorPhotoUrl: String?)
    case userProfile(userId: String)
}

@MainActor
class CityDetailViewModel: ObservableObject {
    @Published var navigationPath = NavigationPath()
    @Published var lists: [CityDetailListRecord] = []
    @Published var topPlaces: [CityTopPlace] = []
    @Published var tiktoks: [CityTikTok] = []
    @Published var reviewPhotos: [CityReviewPhoto] = []
    @Published var activeUsers: [CityActiveUser] = []
    @Published var isLoading: Bool = false
    @Published var placeColors: [UUID: Color] = [:]
    @Published var isLoadingMoreTiktoks: Bool = false
    @Published var hasMoreTiktoks: Bool = true
    @Published var isLoadingMorePhotos: Bool = false
    @Published var hasMorePhotos: Bool = true

    // MARK: - Stats (populated from annotation or fetched)

    @Published var placeCount: Int = 0
    @Published var reviewCount: Int = 0
    @Published var friendCount: Int = 0
    @Published var reviewedPlaceCount: Int = 0
    @Published var hasLoadedStats: Bool = false
    @Published private(set) var hasLoadedContent: Bool = false

    private let placeService = ServiceContainer.shared.placeService
    private let userService = ServiceContainer.shared.userService
    private let tiktokPageSize = 20
    private let photoPageSize = 20
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
        lists.isEmpty && topPlaces.isEmpty && tiktoks.isEmpty && reviewPhotos.isEmpty && activeUsers.isEmpty
    }

    /// Loads all city sections progressively — each section appears as its RPC returns.
    func loadContent(userId: String) async {
        guard !hasLoadedContent else { return }
        isLoading = true
        currentUserId = userId

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadLists(userId: userId) }
            group.addTask { await self.loadTopPlaces(userId: userId) }
            group.addTask { await self.loadTiktoks(userId: userId) }
            group.addTask { await self.loadPhotos(userId: userId) }
            group.addTask { await self.loadActiveUsers(userId: userId) }
            if !hasLoadedStats {
                group.addTask { await self.fetchCityStats(userId: userId) }
            }
        }

        hasLoadedContent = true
        isLoading = false
    }

    /// Toggles follow state for a user with optimistic UI update, reverting on failure.
    func toggleFollow(userId: String) {
        guard let currentUserId = currentUserId else { return }
        guard let index = activeUsers.firstIndex(where: { $0.id == userId }) else { return }
        let wasFollowing = activeUsers[index].isFollowing
        activeUsers[index].isFollowing = !wasFollowing

        if wasFollowing {
            userService.unfollowUser(followerId: currentUserId, followingId: userId) { [weak self] success, _ in
                if !success {
                    Task { @MainActor in
                        if let idx = self?.activeUsers.firstIndex(where: { $0.id == userId }) {
                            self?.activeUsers[idx].isFollowing = true
                        }
                    }
                }
            }
        } else {
            userService.followUser(followerId: currentUserId, followingId: userId) { [weak self] success, _ in
                if !success {
                    Task { @MainActor in
                        if let idx = self?.activeUsers.firstIndex(where: { $0.id == userId }) {
                            self?.activeUsers[idx].isFollowing = false
                        }
                    }
                }
            }
        }
    }

    // MARK: - Navigation

    /// Navigates to the full lists grid view.
    func navigateToAllLists() {
        navigationPath.append(CityDetailDestination.allLists)
    }

    /// Navigates to the full videos grid view.
    func navigateToAllVideos() {
        navigationPath.append(CityDetailDestination.allVideos)
    }

    /// Navigates to the full photos grid view.
    func navigateToAllPhotos() {
        navigationPath.append(CityDetailDestination.allPhotos)
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

    /// Dismisses the city sheet and navigates to a user profile in the main hierarchy.
    func handleUserTap(userId: String, currentUserId: String?, userProfileNavigationViewModel: UserProfileNavigationViewModel) {
        guard let currentUserId, userId != currentUserId else { return }
        PresentationService.shared.dismiss()
        userProfileNavigationViewModel.fetchAndSelectUser(userId: userId, currentUserId: currentUserId)
    }

    // MARK: - Pagination

    /// Triggers pagination when the given photo is the last loaded item.
    func loadMorePhotosIfNeeded(currentPhoto: CityReviewPhoto) {
        guard currentPhoto.id == reviewPhotos.last?.id else { return }
        Task { await loadMorePhotos() }
    }

    /// Loads the next page of review photos for the city.
    func loadMorePhotos() async {
        guard !isLoadingMorePhotos, hasMorePhotos, let userId = currentUserId else { return }
        isLoadingMorePhotos = true
        do {
            let nextPage = try await placeService.fetchCityReviewPhotos(
                userId: userId,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                limit: photoPageSize,
                offset: reviewPhotos.count
            )
            reviewPhotos.append(contentsOf: nextPage)
            hasMorePhotos = nextPage.count == photoPageSize
        } catch {
            print("❌ [CityDetailVM] Error loading more photos: \(error.localizedDescription)")
        }
        isLoadingMorePhotos = false
    }

    /// Loads the next page of TikTok videos for the city.
    func loadMoreTiktoks() async {
        guard !isLoadingMoreTiktoks, hasMoreTiktoks, let userId = currentUserId else { return }
        isLoadingMoreTiktoks = true
        do {
            let nextPage = try await placeService.fetchCityTiktoks(
                userId: userId,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                limit: tiktokPageSize,
                offset: tiktoks.count
            )
            tiktoks.append(contentsOf: nextPage)
            hasMoreTiktoks = nextPage.count == tiktokPageSize
            await prefetchTiktokThumbnails(for: nextPage)
        } catch {
            print("❌ [CityDetailVM] Error loading more tiktoks: \(error.localizedDescription)")
        }
        isLoadingMoreTiktoks = false
    }

    // MARK: - Section Loaders

    /// Fetches lists for the city, with places inlined from the RPC.
    private func loadLists(userId: String) async {
        do {
            let fetched = try await placeService.fetchCityDetailLists(
                userId: userId, latitude: coordinate.latitude, longitude: coordinate.longitude
            )
            self.lists = fetched
        } catch {
            print("❌ [CityDetailVM] Error loading lists: \(error.localizedDescription)")
        }
    }

    /// Fetches top places near the city coordinate.
    private func loadTopPlaces(userId: String) async {
        do {
            let fetched = try await placeService.fetchCityTopPlaces(
                userId: userId, latitude: coordinate.latitude, longitude: coordinate.longitude
            )
            self.topPlaces = fetched
        } catch {
            print("❌ [CityDetailVM] Error loading top places: \(error.localizedDescription)")
        }
    }

    /// Fetches TikTok videos and prefetches their thumbnails.
    private func loadTiktoks(userId: String) async {
        do {
            let fetched = try await placeService.fetchCityTiktoks(
                userId: userId, latitude: coordinate.latitude, longitude: coordinate.longitude
            )
            self.tiktoks = fetched
            self.hasMoreTiktoks = fetched.count == tiktokPageSize
            await prefetchTiktokThumbnails()
        } catch {
            print("❌ [CityDetailVM] Error loading tiktoks: \(error.localizedDescription)")
        }
    }

    /// Fetches review photos for the city.
    private func loadPhotos(userId: String) async {
        do {
            let fetched = try await placeService.fetchCityReviewPhotos(
                userId: userId, latitude: coordinate.latitude, longitude: coordinate.longitude
            )
            self.reviewPhotos = fetched
            self.hasMorePhotos = fetched.count == photoPageSize
        } catch {
            print("❌ [CityDetailVM] Error loading photos: \(error.localizedDescription)")
        }
    }

    /// Fetches active users with follow state inlined from the RPC.
    private func loadActiveUsers(userId: String) async {
        do {
            let fetched = try await placeService.fetchCityActiveUsers(
                userId: userId, latitude: coordinate.latitude, longitude: coordinate.longitude
            )
            self.activeUsers = fetched
        } catch {
            print("❌ [CityDetailVM] Error loading active users: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Methods

    /// Prefetches oEmbed thumbnails for the given TikTok videos.
    private func prefetchTiktokThumbnails(for videos: [CityTikTok]? = nil) async {
        let urls = (videos ?? tiktoks).map(\.url)
        guard !urls.isEmpty else { return }
        await ExternalMetadataCache.shared.prefetchMetadata(for: urls)
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
