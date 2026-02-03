//
//  ProfileTikTokViewModel.swift
//  loc
//
//  Extracted from ProfileViewModel for TikTok/external places management.
//

import SwiftUI

/// Manages TikTok/external places for the current user's profile.
@MainActor
class ProfileTikTokViewModel: ObservableObject {
    // MARK: - Published Properties - External Places

    /// Lightweight external/TikTok places for display
    @Published var lightweightExternalPlaces: [LightweightPlace] = []

    /// Total external places count from database
    @Published var totalExternalPlacesCount: Int = 0

    /// Dictionary of external places by place ID
    @Published var userExternalPlaces: [String: ExternalPlace] = [:]

    /// Loading state for initial load
    @Published var isLoadingTikTokPlaces: Bool = false

    /// Loading state for pagination
    @Published var isLoadingMoreExternalPlaces: Bool = false

    /// Whether more external places can be loaded
    @Published var hasMoreExternalPlaces: Bool = true

    /// Loading more TikTok places state
    @Published var isLoadingMoreTikTokPlaces: Bool = false

    // MARK: - Published Properties - TikTok Import

    /// Whether TikTok processing is in progress
    @Published var isProcessingTikTok: Bool = false

    /// Whether waiting for place detail after TikTok import
    @Published var isWaitingForPlaceDetail: Bool = false

    /// TikTok import error message
    @Published var tikTokImportError: String? = nil

    /// Imported places from TikTok
    @Published var importedPlaces: [DetailPlace] = []

    // MARK: - Sheet Presentation (via PresentationService)

    /// Whether showing place selection sheet (reads from PresentationService).
    var isShowingPlaceSelection: Bool {
        get { PresentationService.shared.activeSheet == .tikTokPlaceSelection }
        set {
            if newValue {
                PresentationService.shared.present(.tikTokPlaceSelection)
            } else if PresentationService.shared.activeSheet == .tikTokPlaceSelection {
                PresentationService.shared.dismiss()
            }
        }
    }

    /// Whether showing no places found alert (reads from PresentationService).
    var isShowingNoPlacesFound: Bool {
        get {
            guard let sheet = PresentationService.shared.activeSheet else { return false }
            if case .tikTokNoPlacesFound = sheet { return true }
            return false
        }
        set {
            if newValue {
                PresentationService.shared.present(.tikTokNoPlacesFound(tikTokUrl: noPlacesFoundTikTokUrl))
            } else if case .tikTokNoPlacesFound = PresentationService.shared.activeSheet {
                PresentationService.shared.dismiss()
            }
        }
    }

    /// TikTok URL when no places were found
    @Published var noPlacesFoundTikTokUrl: String = ""

    // MARK: - Published Properties - TikTok Flags

    /// TikTok place flags by place ID
    @Published var tikTokPlaceFlags: [String: TikTokPlaceFlag] = [:]

    // MARK: - Private State

    private var currentProcessingTikTokUrl: String? = nil
    private var recentlyProcessedURLs: Set<String> = []
    private var _hasMoreTikTokPlaces: Bool = true
    private var currentTikTokPage: Int = 0
    private let tikTokPlacesPerPage: Int = 8
    var allTikTokPlaceIds: [String] = []
    private var loadedTikTokPlaceIds: [String] = []

    /// Track whether we've already prefetched metadata to avoid duplicate calls
    private var prefetchedMetadataForSession: Set<String> = []

    // MARK: - Dependencies

    private let userService: UserService
    private weak var userSession: UserSession?

    // MARK: - Callbacks for Cross-Cutting Concerns

    /// Callback to refresh TikTok places after import (wired by parent ViewModel).
    var onRefreshTikTokPlaces: (() -> Void)?

    /// Callback to set a place image (wired by parent ViewModel to update detailPlaceViewModel).
    var onPlaceImageLoaded: ((String, UIImage) -> Void)?

    /// Callback to check if a place image exists (wired by parent ViewModel).
    var hasPlaceImage: ((String) -> Bool)?

    /// Callback to fetch a place image (wired by parent ViewModel).
    var onFetchPlaceImage: ((String) -> Void)?

    /// Callback to get the current user ID.
    var getCurrentUserId: (() -> String?)?

    /// Callback to update placeSavers (placeId, userId, isAdding).
    var onPlaceSaversUpdate: ((String, String, Bool) -> Void)?

    /// Callback to remove a place from places dictionary.
    var onPlacesRemove: ((String) -> Void)?

    /// Callback to recalculate annotation places.
    var onAnnotationPlacesRecalculate: (() -> Void)?

    // MARK: - Initialization

    /// Initializes the TikTok view model with required dependencies.
    init(userService: UserService, userSession: UserSession) {
        self.userService = userService
        self.userSession = userSession
    }

    // MARK: - External Places Loading

    /// Loads initial external places (TikTok places).
    func loadInitialExternalPlaces() async {
        guard let userId = userSession?.currentUserId else {
            print("⚠️ [ProfileTikTokViewModel] Cannot load initial external places: no user ID")
            return
        }

        // Don't reload if already loading or if we have data
        guard !isLoadingTikTokPlaces && lightweightExternalPlaces.isEmpty else {
            return
        }

        isLoadingTikTokPlaces = true

        defer {
            isLoadingTikTokPlaces = false
        }

        do {
            // Fetch first page and total count in parallel
            async let placesTask = userService.fetchUserExternalPlaces(userId: userId, limit: 8, offset: 0)
            async let countTask = userService.getNumberExternalPlaces(forUserId: userId)

            let lightweightPlaces = try await placesTask
            let totalCount = (try? await countTask) ?? 0

            // Prefetch TikTok metadata (non-blocking) - only for URLs not already prefetched
            let tiktokUrls = lightweightPlaces.compactMap { $0.tiktok_url }.filter { !$0.isEmpty }
            let newUrls = tiktokUrls.filter { !prefetchedMetadataForSession.contains($0) }
            if !newUrls.isEmpty {
                prefetchedMetadataForSession.formUnion(newUrls)
                Task {
                    await TikTokMetadataCache.shared.prefetchMetadata(for: newUrls)
                }
            }

            lightweightExternalPlaces = lightweightPlaces
            totalExternalPlacesCount = totalCount
            hasMoreExternalPlaces = !lightweightPlaces.isEmpty && lightweightPlaces.count >= 8
        } catch {
            print("❌ [ProfileTikTokViewModel] Error loading initial external places: \(error.localizedDescription)")
            hasMoreExternalPlaces = false
        }
    }

    /// Loads more external places (pagination).
    func loadMoreExternalPlaces() async {
        guard let userId = userSession?.currentUserId else {
            print("⚠️ [ProfileTikTokViewModel] Cannot load more external places: no user ID")
            return
        }

        guard !isLoadingMoreExternalPlaces && hasMoreExternalPlaces else {
            return
        }

        let offset = lightweightExternalPlaces.count

        isLoadingMoreExternalPlaces = true

        defer {
            isLoadingMoreExternalPlaces = false
        }

        do {
            let lightweightPlaces = try await userService.fetchUserExternalPlaces(userId: userId, limit: 8, offset: offset)

            // Prefetch TikTok metadata (non-blocking) - only for URLs not already prefetched
            let tiktokUrls = lightweightPlaces.compactMap { $0.tiktok_url }.filter { !$0.isEmpty }
            let newUrls = tiktokUrls.filter { !prefetchedMetadataForSession.contains($0) }
            if !newUrls.isEmpty {
                prefetchedMetadataForSession.formUnion(newUrls)
                Task {
                    await TikTokMetadataCache.shared.prefetchMetadata(for: newUrls)
                }
            }

            // Deduplicate
            let existingIds = Set(lightweightExternalPlaces.map { $0.id })
            let newUniquePlaces = lightweightPlaces.filter { !existingIds.contains($0.id) }

            if !newUniquePlaces.isEmpty {
                lightweightExternalPlaces.append(contentsOf: newUniquePlaces)
            }

            hasMoreExternalPlaces = !lightweightPlaces.isEmpty && lightweightPlaces.count >= 8
        } catch {
            print("❌ [ProfileTikTokViewModel] Error loading more external places: \(error.localizedDescription)")
            hasMoreExternalPlaces = false
        }
    }

    /// Reloads lightweight external places from database.
    func reloadLightweightExternalPlaces() async {
        guard let userId = userSession?.currentUserId else {
            print("⚠️ [ProfileTikTokViewModel] Cannot reload external places: no user ID")
            return
        }

        isLoadingTikTokPlaces = true

        do {
            async let placesTask = userService.fetchUserExternalPlaces(userId: userId, limit: 8, offset: 0)
            async let countTask = userService.getNumberExternalPlaces(forUserId: userId)

            let lightweightPlaces = try await placesTask
            let totalCount = (try? await countTask) ?? 0

            lightweightExternalPlaces = lightweightPlaces
            totalExternalPlacesCount = totalCount
            hasMoreExternalPlaces = !lightweightPlaces.isEmpty && lightweightPlaces.count >= 8
        } catch {
            print("❌ [ProfileTikTokViewModel] Error reloading external places: \(error.localizedDescription)")
        }

        isLoadingTikTokPlaces = false
    }

    /// Refreshes TikTok places after import.
    func refreshTikTokPlacesAfterImport() {
        Task {
            await reloadLightweightExternalPlaces()
        }
    }

    // MARK: - TikTok Place Flagging

    /// Flags a TikTok place.
    func flagTikTokPlace(for placeId: String, flagType: TikTokPlaceFlagType, tikTokUrl: String? = nil, userComment: String? = nil) {
        guard let userId = userSession?.currentUserId else { return }

        let flag = TikTokPlaceFlag(
            placeId: placeId,
            userId: userId,
            flagType: flagType,
            tikTokUrl: tikTokUrl,
            userComment: userComment
        )

        tikTokPlaceFlags[placeId] = flag

        userService.saveTikTokPlaceFlag(flag: flag) { [weak self] success, error in
            if !success {
                print("❌ [ProfileTikTokViewModel] Error flagging TikTok place: \(error?.localizedDescription ?? "unknown")")
                DispatchQueue.main.async {
                    self?.tikTokPlaceFlags.removeValue(forKey: placeId)
                }
            }
        }
    }

    /// Loads a TikTok place flag.
    func loadTikTokPlaceFlag(for placeId: String) {
        guard let userId = userSession?.currentUserId else { return }

        userService.hasUserFlaggedPlace(userId: userId, placeId: placeId) { [weak self] flag, error in
            DispatchQueue.main.async {
                if let flag = flag {
                    self?.tikTokPlaceFlags[placeId] = flag
                }
            }
        }
    }

    /// Removes a TikTok place flag.
    func removeTikTokPlaceFlag(for placeId: String) {
        guard let userId = userSession?.currentUserId else { return }

        let removedFlag = tikTokPlaceFlags.removeValue(forKey: placeId)

        userService.deleteTikTokPlaceFlag(userId: userId, placeId: placeId) { [weak self] success, error in
            if !success {
                print("❌ [ProfileTikTokViewModel] Error removing TikTok place flag: \(error?.localizedDescription ?? "unknown")")
                DispatchQueue.main.async {
                    if let flag = removedFlag {
                        self?.tikTokPlaceFlags[placeId] = flag
                    }
                }
            }
        }
    }

    /// Gets a TikTok place flag.
    func getTikTokPlaceFlag(for placeId: String) -> TikTokPlaceFlag? {
        return tikTokPlaceFlags[placeId]
    }

    /// Checks if a TikTok place has been flagged.
    func hasFlaggedTikTokPlace(placeId: String) -> Bool {
        return tikTokPlaceFlags[placeId] != nil
    }

    // MARK: - TikTok Video Access

    /// Checks if user has TikTok videos for a place using cached data.
    func hasTikTokVideos(for placeId: String) -> Bool {
        return userExternalPlaces.values.contains { $0.placeId == placeId && $0.url != nil && !$0.url!.isEmpty }
    }

    /// Gets external place for a place ID.
    func getExternalPlace(for placeId: String) -> ExternalPlace? {
        return userExternalPlaces.values.first { $0.placeId == placeId }
    }

    /// Gets the first TikTok thumbnail URL for a place.
    func getFirstTikTokThumbnailURL(for placeId: String) -> String? {
        guard let externalPlace = userExternalPlaces.values.first(where: { $0.placeId == placeId && $0.url != nil }),
              let url = externalPlace.url,
              let metadata = TikTokMetadataCache.shared.getCachedMetadata(for: url) else {
            return nil
        }
        return metadata.thumbnailURL
    }

    // MARK: - TikTok Import State

    /// Clears TikTok import error.
    func clearTikTokImportError() {
        tikTokImportError = nil
    }

    /// Removes a place from local TikTok state.
    func removeFromLocalTikTokState(placeId: String) {
        lightweightExternalPlaces.removeAll { $0.place_id == placeId }
        allTikTokPlaceIds.removeAll { $0 == placeId }
        loadedTikTokPlaceIds.removeAll { $0 == placeId }

        if totalExternalPlacesCount > 0 {
            totalExternalPlacesCount -= 1
        }
    }

    // MARK: - Fetch User External Places (for dictionary)

    /// Populates the userExternalPlaces dictionary for TikTok place deletion and quick lookups.
    func fetchUserExternalPlaces() async {
        guard let userId = userSession?.currentUserId else {
            print("❌ [ProfileTikTokViewModel] No user ID available for fetching external places")
            return
        }

        do {
            let externalPlaces = try await userService.fetchAllUserExternalPlaces(userId: userId)

            var placesDict: [String: ExternalPlace] = [:]
            for place in externalPlaces {
                placesDict[place.id] = place
            }

            userExternalPlaces = placesDict

            // Prefetch TikTok metadata - only for URLs not already prefetched
            let tiktokUrls = externalPlaces.compactMap { $0.url }.filter { !$0.isEmpty }
            let newUrls = tiktokUrls.filter { !prefetchedMetadataForSession.contains($0) }
            if !newUrls.isEmpty {
                prefetchedMetadataForSession.formUnion(newUrls)
                Task {
                    await TikTokMetadataCache.shared.prefetchMetadata(for: newUrls)
                }
            }
        } catch {
            print("❌ [ProfileTikTokViewModel] Error fetching external places: \(error.localizedDescription)")
        }
    }

    // MARK: - External Places Image Loading

    /// Ensures a TikTok thumbnail is cached for display.
    func ensureTikTokThumbnailCached(for placeId: String) {
        if hasPlaceImage?(placeId) == true {
            return
        }

        Task { [weak self] in
            await self?.fetchFallbackImages(for: [placeId])
        }
    }

    /// Fetches fallback images for places from multiple sources.
    func fetchFallbackImages(for placeIds: [String]) async {
        var remaining = placeIds.filter { hasPlaceImage?($0) != true }
        guard !remaining.isEmpty else { return }

        guard let userId = getCurrentUserId?() else { return }

        // Try TikTok thumbnails first
        do {
            let urlMap = try await SupabaseUserService.shared.fetchExternalPlaceURLs(placeIds: Array(remaining), userId: userId)

            for placeId in remaining {
                guard let url = urlMap[placeId], !url.isEmpty else { continue }
                guard hasPlaceImage?(placeId) != true else { continue }

                guard let video = await TikTokMetadataCache.shared.getMetadata(for: url) else { continue }
                let thumbnailURL = video.thumbnailURL
                guard !thumbnailURL.isEmpty else { continue }

                loadRemoteImageAsPlaceImage(placeId: placeId, imageURL: thumbnailURL)
            }
        } catch {
            print("❌ [ProfileTikTokViewModel] Error fetching TikTok thumbnails: \(error.localizedDescription)")
        }

        remaining = remaining.filter { hasPlaceImage?($0) != true }
        guard !remaining.isEmpty else { return }

        // Try regular user reviews (from reviews table)
        do {
            let regularReviewImages = try await SupabaseUserService.shared.fetchRegularReviewImages(for: Array(remaining))
            for (placeId, imageUrl) in regularReviewImages {
                guard hasPlaceImage?(placeId) != true else { continue }
                loadRemoteImageAsPlaceImage(placeId: placeId, imageURL: imageUrl)
            }
        } catch {
            print("❌ [ProfileTikTokViewModel] Error fetching regular review images: \(error.localizedDescription)")
        }

        remaining = remaining.filter { hasPlaceImage?($0) != true }
        guard !remaining.isEmpty else { return }

        // Finally try external reviews (from external_reviews table)
        do {
            let externalReviewImages = try await SupabaseUserService.shared.fetchExternalReviewImages(for: Array(remaining))
            for (placeId, imageUrl) in externalReviewImages {
                guard hasPlaceImage?(placeId) != true else { continue }
                loadRemoteImageAsPlaceImage(placeId: placeId, imageURL: imageUrl)
            }
        } catch {
            print("❌ [ProfileTikTokViewModel] Error fetching external review images: \(error.localizedDescription)")
        }
    }

    /// Loads an image from a remote URL and stores it via callback.
    private func loadRemoteImageAsPlaceImage(placeId: String, imageURL: String) {
        if hasPlaceImage?(placeId) == true {
            return
        }

        guard let url = URL(string: imageURL) else {
            print("❌ [ProfileTikTokViewModel] Invalid image URL for place \(placeId): \(imageURL)")
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ [ProfileTikTokViewModel] Error loading image for \(placeId): \(error.localizedDescription)")
                } else if let data = data, let image = UIImage(data: data) {
                    self?.onPlaceImageLoaded?(placeId, image)
                } else {
                    print("⚠️ [ProfileTikTokViewModel] No image data returned for place \(placeId)")
                }
            }
        }.resume()
    }

    /// Loads an image from URL asynchronously.
    private func loadImageFromURL(imageUrl: String, placeId: String) async {
        guard let url = URL(string: imageUrl) else {
            print("❌ [ProfileTikTokViewModel] Invalid image URL for place \(placeId): \(imageUrl)")
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                await MainActor.run {
                    self.onPlaceImageLoaded?(placeId, image)
                }
            }
        } catch {
            print("❌ [ProfileTikTokViewModel] Error loading image for \(placeId): \(error.localizedDescription)")
        }
    }

    /// Loads TikTok thumbnail as place image.
    func loadTikTokThumbnailAsPlaceImage(placeId: String, thumbnailURL: String) async {
        guard let url = URL(string: thumbnailURL) else {
            print("❌ [ProfileTikTokViewModel] Invalid thumbnail URL for place \(placeId): \(thumbnailURL)")
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                await MainActor.run {
                    self.onPlaceImageLoaded?(placeId, image)
                }
            } else {
                print("⚠️ [ProfileTikTokViewModel] No image data returned for TikTok thumbnail \(placeId)")
            }
        } catch {
            print("❌ [ProfileTikTokViewModel] Error loading TikTok thumbnail for \(placeId): \(error.localizedDescription)")
        }
    }

    /// Loads images for places with prioritization.
    func loadPriorityImagesForPlaces(_ places: [DetailPlace], priorityCount: Int = 8) {
        let priorityPlaces = Array(places.prefix(priorityCount))
        let remainingPlaces = Array(places.dropFirst(priorityCount))

        // Load priority places immediately
        for place in priorityPlaces {
            onFetchPlaceImage?(place.id.uuidString)
        }

        // Load remaining places in background
        if !remainingPlaces.isEmpty {
            Task.detached(priority: .background) { [weak self] in
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

                for place in remainingPlaces {
                    await MainActor.run {
                        self?.onFetchPlaceImage?(place.id.uuidString)
                    }
                    try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                }
            }
        }
    }

    // MARK: - External Place Lookups

    /// Gets external_place_id for a TikTok video URL at a specific place.
    func getExternalPlaceId(for placeId: String, videoUrl: String) async -> String? {
        guard let userId = getCurrentUserId?() else {
            return nil
        }

        do {
            let urlPairs = try await userService.fetchExternalPlaceURLs(placeId: placeId, userId: userId)
            return urlPairs.first(where: { $0.url == videoUrl })?.id
        } catch {
            print("❌ [ProfileTikTokViewModel] Error fetching external_place_id: \(error)")
            return nil
        }
    }

    /// Gets TikTok videos for a place using cached metadata.
    func getTikTokVideosSync(for placeId: String) -> [TikTokVideo] {
        print("🎬 [ProfileTikTokViewModel] getTikTokVideosSync for placeId: \(placeId)")
        print("  - userExternalPlaces count: \(userExternalPlaces.count)")

        let matchingPlaces = userExternalPlaces.values.filter { $0.placeId == placeId && $0.url != nil && !$0.url!.isEmpty }
        print("  - matchingPlaces for this placeId: \(matchingPlaces.count)")
        let currentUserId = getCurrentUserId?()

        var videos: [TikTokVideo] = []
        for externalPlace in matchingPlaces {
            guard let url = externalPlace.url else { continue }

            if var video = TikTokMetadataCache.shared.getCachedMetadata(for: url) {
                video.savedByUserId = currentUserId
                video.externalPlaceId = externalPlace.id
                videos.append(video)
            } else {
                let videoId = extractVideoIdFromTikTokURL(url) ?? UUID().uuidString
                var basicVideo = TikTokVideo(
                    videoID: videoId,
                    url: url,
                    title: nil,
                    caption: nil,
                    embedHTML: "",
                    thumbnailURL: "",
                    author: TikTokAuthor(displayName: "", url: "", username: ""),
                    hashtags: [],
                    createdAt: ISO8601DateFormatter().string(from: Date())
                )
                basicVideo.savedByUserId = currentUserId
                basicVideo.externalPlaceId = externalPlace.id
                videos.append(basicVideo)
            }
        }

        print("  - Returning \(videos.count) videos")
        return videos
    }

    /// Extracts video ID from TikTok URL.
    private func extractVideoIdFromTikTokURL(_ url: String) -> String? {
        let patterns = [
            "/photo/([0-9]+)",
            "/video/([0-9]+)",
            "@[^/]+/video/([0-9]+)"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: url, range: NSRange(location: 0, length: url.count)),
               let range = Range(match.range(at: 1), in: url) {
                return String(url[range])
            }
        }

        return nil
    }

    // MARK: - Reset

    /// Resets all TikTok data (used during logout).
    func resetAllData() {
        lightweightExternalPlaces.removeAll()
        totalExternalPlacesCount = 0
        userExternalPlaces.removeAll()
        isLoadingTikTokPlaces = false
        isLoadingMoreExternalPlaces = false
        hasMoreExternalPlaces = true
        isLoadingMoreTikTokPlaces = false
        isProcessingTikTok = false
        isWaitingForPlaceDetail = false
        tikTokImportError = nil
        importedPlaces.removeAll()
        isShowingPlaceSelection = false
        isShowingNoPlacesFound = false
        noPlacesFoundTikTokUrl = ""
        tikTokPlaceFlags.removeAll()
        currentProcessingTikTokUrl = nil
        recentlyProcessedURLs.removeAll()
        _hasMoreTikTokPlaces = true
        currentTikTokPage = 0
        allTikTokPlaceIds.removeAll()
        loadedTikTokPlaceIds.removeAll()
        prefetchedMetadataForSession.removeAll()
    }

    // MARK: - TikTok Place Deletion

    /// Deletes a TikTok place with completion handler.
    func deleteTikTokPlace(_ place: DetailPlace, completion: @escaping (Bool) -> Void) {
        guard let userId = getCurrentUserId?() else {
            completion(false)
            return
        }

        let placeId = place.id.uuidString

        // Optimistic update: Remove from all local collections immediately
        removeFromLocalTikTokStateWithMapUpdate(placeId: placeId, userId: userId)

        // Call backend to delete the TikTok place
        userService.deleteTikTokPlace(userId: userId, placeId: placeId) { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ [ProfileTikTokViewModel] Error deleting TikTok place: \(error.localizedDescription)")
                    completion(false)
                } else {
                    completion(true)
                }
            }
        }
    }

    /// Delete a TikTok place using LightweightPlace (for popup views).
    func deleteTikTokPlace(_ place: LightweightPlace) {
        guard let userId = getCurrentUserId?() else { return }

        let placeId = place.place_id

        // Optimistic update: Remove from all local collections immediately
        removeFromLocalTikTokStateWithMapUpdate(placeId: placeId, userId: userId)

        // Persist deletion to backend
        userService.deleteTikTokPlace(userId: userId, placeId: placeId) { error in
            if let error = error {
                print("❌ [ProfileTikTokViewModel] Error deleting TikTok place: \(error.localizedDescription)")
            }
        }
    }

    /// Removes TikTok place from all local state collections and updates map.
    private func removeFromLocalTikTokStateWithMapUpdate(placeId: String, userId: String) {
        // Remove from TikTok-specific state
        removeFromLocalTikTokState(placeId: placeId)
        userExternalPlaces.removeValue(forKey: placeId)

        // Cross-cutting map concerns via callbacks
        onPlaceSaversUpdate?(placeId, userId, false)
        onPlacesRemove?(placeId)
        onAnnotationPlacesRecalculate?()
    }

    /// Updates a TikTok place association by external place ID.
    func updateTikTokPlaceById(externalPlaceId: String, newPlaceId: String, newPlaceName: String) async {
        guard let userId = getCurrentUserId?() else {
            print("❌ [ProfileTikTokViewModel] Cannot update TikTok place: missing userId")
            return
        }

        // Find the existing place to get old placeId for tracking updates
        let existingPlace = lightweightExternalPlaces.first { $0.external_place_id == externalPlaceId }
        let oldPlaceId = existingPlace?.place_id

        // Optimistic update: Update local state immediately
        if let index = lightweightExternalPlaces.firstIndex(where: { $0.external_place_id == externalPlaceId }) {
            let original = lightweightExternalPlaces[index]
            let updatedPlace = LightweightPlace(
                place_id: newPlaceId,
                name: newPlaceName,
                latest_review_photo: original.latest_review_photo,
                external_place_id: externalPlaceId,
                tiktok_url: original.tiktok_url,
                added_by_user_id: original.added_by_user_id,
                added_by_name: original.added_by_name,
                added_by_photo_url: original.added_by_photo_url
            )
            lightweightExternalPlaces[index] = updatedPlace
        }

        // Update ID tracking
        if let old = oldPlaceId {
            allTikTokPlaceIds.removeAll { $0 == old }
        }
        if !allTikTokPlaceIds.contains(newPlaceId) {
            allTikTokPlaceIds.append(newPlaceId)
        }

        // Persist to backend
        do {
            try await userService.updateTikTokPlaceAssociation(
                externalPlaceId: externalPlaceId,
                newPlaceId: newPlaceId,
                userId: userId
            )
            print("✅ [ProfileTikTokViewModel] Updated TikTok place to \(newPlaceId)")
        } catch {
            print("❌ [ProfileTikTokViewModel] Error updating TikTok place: \(error.localizedDescription)")
            // Revert optimistic update on failure
            onRefreshTikTokPlaces?()
        }
    }

    // MARK: - TikTok URL Processing

    /// Processes a shared TikTok URL and extracts place information.
    func processSharedTikTokURL(
        _ urlString: String,
        tikTokService: TikTokService,
        selectedPlaceVM: SelectedPlaceViewModel,
        placeVM: DetailPlaceViewModel,
        deepLinkManager: DeepLinkManager?,
        deepLinkViewModel: DeepLinkViewModel?
    ) async -> Bool {
        // Check if this URL was recently processed
        if recentlyProcessedURLs.contains(urlString) {
            print("⚠️ [ProfileTikTokViewModel] URL already processed recently, skipping: \(urlString)")
            return false
        }

        // Check if already processing
        if isProcessingTikTok {
            print("⚠️ [ProfileTikTokViewModel] Already processing a TikTok URL, skipping: \(urlString)")
            return false
        }

        // Mark as processing and add to recently processed
        await MainActor.run {
            isProcessingTikTok = true
            recentlyProcessedURLs.insert(urlString)
            currentProcessingTikTokUrl = urlString
        }

        let result = await tikTokService.processTikTokURL(urlString)

        // Clear from recently processed after 30 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) {
            self.recentlyProcessedURLs.remove(urlString)
        }

        switch result {
        case .success(let detailPlaces):
            tikTokImportError = nil

            await handleSuccessfulTikTokProcessing(
                detailPlaces: detailPlaces,
                urlString: urlString,
                selectedPlaceVM: selectedPlaceVM,
                placeVM: placeVM,
                deepLinkManager: deepLinkManager
            )

            return true

        case .failure(let error):
            print("❌ [ProfileTikTokViewModel] TikTok processing failed: \(error.localizedDescription)")

            await MainActor.run {
                setTikTokErrorMessage(from: error)
                isProcessingTikTok = false
                deepLinkManager?.isProcessingDeepLink = false
                currentProcessingTikTokUrl = nil
            }

            return false
        }
    }

    /// Handles successful TikTok URL processing with extracted places.
    private func handleSuccessfulTikTokProcessing(
        detailPlaces: [DetailPlace],
        urlString: String,
        selectedPlaceVM: SelectedPlaceViewModel,
        placeVM: DetailPlaceViewModel,
        deepLinkManager: DeepLinkManager?
    ) async {
        await MainActor.run {
            if detailPlaces.count == 1 {
                handleSinglePlace(
                    detailPlaces[0],
                    urlString: urlString,
                    selectedPlaceVM: selectedPlaceVM,
                    placeVM: placeVM,
                    deepLinkManager: deepLinkManager
                )
            } else if detailPlaces.count > 1 {
                handleMultiplePlacesFromProcessing(
                    detailPlaces,
                    urlString: urlString,
                    placeVM: placeVM,
                    deepLinkManager: deepLinkManager
                )
            } else {
                handleNoPlacesFound(urlString: urlString, deepLinkManager: deepLinkManager)
            }
        }
    }

    /// Handles a single place result from TikTok processing.
    private func handleSinglePlace(
        _ detailPlace: DetailPlace,
        urlString: String,
        selectedPlaceVM: SelectedPlaceViewModel,
        placeVM: DetailPlaceViewModel,
        deepLinkManager: DeepLinkManager?
    ) {
        // Validate place has a name
        if detailPlace.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            print("❌ [ProfileTikTokViewModel] Single place found but has no name")
            noPlacesFoundTikTokUrl = urlString
            isShowingNoPlacesFound = true
            isProcessingTikTok = false
            deepLinkManager?.isProcessingDeepLink = false
            return
        }

        placeVM.places[detailPlace.id.uuidString] = detailPlace

        // Add current user as saver so pin shows with profile
        Task {
            if let uid = await SupabaseAuthService.shared.currentUserId {
                await MainActor.run {
                    placeVM.placeSavers[detailPlace.id.uuidString] = [uid]
                }
            }
        }

        placeVM.calculateAnnotationPlaces()
        selectedPlaceVM.selectPlaceAndFetchDetails(detailPlace, shouldAnimateMap: true)
        selectedPlaceVM.isDetailSheetPresented = true

        // Clear loading states immediately
        isProcessingTikTok = false
        isWaitingForPlaceDetail = false
        deepLinkManager?.isProcessingDeepLink = false
        currentProcessingTikTokUrl = nil
    }

    /// Handles multiple places result from TikTok processing.
    private func handleMultiplePlacesFromProcessing(
        _ detailPlaces: [DetailPlace],
        urlString: String,
        placeVM: DetailPlaceViewModel,
        deepLinkManager: DeepLinkManager?
    ) {
        print("🎯 [ProfileTikTokViewModel] MULTIPLE PLACES DETECTED: \(detailPlaces.count) places")

        // Validate all places have names
        let validPlaces = detailPlaces.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        for place in validPlaces {
            print("   ✓ \(place.name)")
        }

        if validPlaces.isEmpty {
            print("❌ [ProfileTikTokViewModel] No valid places found after filtering")
            noPlacesFoundTikTokUrl = urlString
            isShowingNoPlacesFound = true
            isProcessingTikTok = false
            deepLinkManager?.isProcessingDeepLink = false
            return
        }

        // Add all valid places to place manager
        for place in validPlaces {
            placeVM.places[place.id.uuidString] = place
        }

        importedPlaces = validPlaces
        isShowingPlaceSelection = true

        // Clear loading states
        isProcessingTikTok = false
        isWaitingForPlaceDetail = false
        deepLinkManager?.isProcessingDeepLink = false
    }

    /// Handles the case when no places are found from TikTok processing.
    private func handleNoPlacesFound(urlString: String, deepLinkManager: DeepLinkManager?) {
        print("❌ [ProfileTikTokViewModel] No places found")
        noPlacesFoundTikTokUrl = urlString
        isShowingNoPlacesFound = true
        isProcessingTikTok = false
        isWaitingForPlaceDetail = false
        deepLinkManager?.isProcessingDeepLink = false
    }

    /// Sets a user-friendly error message based on the error type.
    private func setTikTokErrorMessage(from error: Error) {
        if error.localizedDescription.contains("network") || error.localizedDescription.contains("Internet") {
            tikTokImportError = "Please check your internet connection and try again"
        } else if error.localizedDescription.contains("invalid") || error.localizedDescription.contains("URL") {
            tikTokImportError = "This doesn't appear to be a valid TikTok URL"
        } else {
            tikTokImportError = "We couldn't find any places in this TikTok video. Try sharing a different video that shows specific locations"
        }
    }

    /// Clears place selection state and refreshes TikTok places.
    func clearPlaceSelection() {
        importedPlaces = []
        isShowingPlaceSelection = false
        currentProcessingTikTokUrl = nil

        // Refresh TikTok places list after clearing selection
        onRefreshTikTokPlaces?()
    }

    /// Clears the no places found state.
    func clearNoPlacesFound(deepLinkManager: DeepLinkManager?, deepLinkViewModel: DeepLinkViewModel?) {
        isShowingNoPlacesFound = false
        noPlacesFoundTikTokUrl = ""
        // Ensure processing states are cleared when user closes the view
        isProcessingTikTok = false
        isWaitingForPlaceDetail = false
        deepLinkManager?.isProcessingDeepLink = false
        deepLinkViewModel?.isProcessingDeepLink = false
    }

    /// Called when the place selection view appears.
    func placeSelectionViewAppeared(deepLinkManager: DeepLinkManager?, deepLinkViewModel: DeepLinkViewModel?) {
        isWaitingForPlaceDetail = false
        isProcessingTikTok = false
        deepLinkManager?.isProcessingDeepLink = false
        deepLinkViewModel?.isProcessingDeepLink = false
    }

    /// Handles multiple places received from notifications.
    func handleMultiplePlaces(_ places: [DetailPlace]) {
        print("🎯 [ProfileTikTokViewModel] Received \(places.count) places")
        for place in places {
            print("   - \(place.name) (ID: \(place.id))")
        }

        importedPlaces = places
        isShowingPlaceSelection = true

        print("🎯 [ProfileTikTokViewModel] Set isShowingPlaceSelection = true")
    }

    /// Handles multiple places notification with TikTok URL.
    func handleMultiplePlacesNotification(places: [DetailPlace], tikTokUrl: String?) {
        print("🎯 [ProfileTikTokViewModel] Handling multiple places notification with TikTok URL")
        if let tikTokUrl = tikTokUrl {
            currentProcessingTikTokUrl = tikTokUrl
        }
        handleMultiplePlaces(places)
    }

    /// Handles TikTok notification and processes the URL.
    func handleTikTokNotification(
        url: String,
        tikTokService: TikTokService,
        selectedPlaceVM: SelectedPlaceViewModel,
        placeVM: DetailPlaceViewModel,
        deepLinkManager: DeepLinkManager?,
        deepLinkViewModel: DeepLinkViewModel?
    ) {
        Task {
            await processSharedTikTokURL(
                url,
                tikTokService: tikTokService,
                selectedPlaceVM: selectedPlaceVM,
                placeVM: placeVM,
                deepLinkManager: deepLinkManager,
                deepLinkViewModel: deepLinkViewModel
            )
        }
    }

    /// Checks UserDefaults for a pending TikTok URL and processes it.
    func checkPendingTikTokURL(
        tikTokService: TikTokService,
        selectedPlaceVM: SelectedPlaceViewModel,
        placeVM: DetailPlaceViewModel,
        deepLinkManager: DeepLinkManager?,
        deepLinkViewModel: DeepLinkViewModel?
    ) {
        if let pendingURL = UserDefaults.standard.string(forKey: "pendingTikTokURL") {
            Task {
                await processSharedTikTokURL(
                    pendingURL,
                    tikTokService: tikTokService,
                    selectedPlaceVM: selectedPlaceVM,
                    placeVM: placeVM,
                    deepLinkManager: deepLinkManager,
                    deepLinkViewModel: deepLinkViewModel
                )
            }
            UserDefaults.standard.removeObject(forKey: "pendingTikTokURL")
        }
    }
}
