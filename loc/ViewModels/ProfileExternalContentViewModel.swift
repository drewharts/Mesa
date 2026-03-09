//
//  ProfileExternalContentViewModel.swift
//  loc
//
//  Extracted from ProfileViewModel for external places management.
//

import SwiftUI
import MapKit

/// Manages external places for the current user's profile.
@MainActor
class ProfileExternalContentViewModel: ObservableObject {
    // MARK: - Published Properties - External Places

    /// Lightweight external places for display
    @Published var lightweightExternalPlaces: [LightweightPlace] = []

    /// Total external places count from database
    @Published var totalExternalPlacesCount: Int = 0

    /// Dictionary of external places by place ID
    @Published var userExternalPlaces: [String: ExternalPlace] = [:]

    /// Loading state for initial load
    @Published var isLoadingExternalPlaces: Bool = false

    /// Loading state for pagination
    @Published var isLoadingMoreExternalPlaces: Bool = false

    /// Whether more external places can be loaded
    @Published var hasMoreExternalPlaces: Bool = true

    // MARK: - Published Properties - Nearby Filter

    /// Whether the "Nearby" viewport filter is active
    @Published var isNearbyFilterEnabled: Bool = false

    /// Current map region for viewport-based filtering
    var currentMapRegion: MKCoordinateRegion?

    /// All nearby places with coordinates for client-side viewport filtering
    private var allNearbyPlaces: [LightweightPlace] = []

    /// Whether the full nearby dataset has been loaded
    private var hasLoadedAllNearbyPlaces: Bool = false

    // MARK: - Published Properties - Content Import

    /// Whether content processing is in progress
    @Published var isProcessingContent: Bool = false

    /// Whether waiting for place detail after content import
    @Published var isWaitingForPlaceDetail: Bool = false

    /// Import error message
    @Published var importError: String? = nil

    /// Imported places from external content
    @Published var importedPlaces: [DetailPlace] = []

    // MARK: - Sheet Presentation (via PresentationService)

    /// Whether showing place selection sheet (reads from PresentationService).
    var isShowingPlaceSelection: Bool {
        get { PresentationService.shared.activeSheet == .externalPlaceSelection }
        set {
            if newValue {
                PresentationService.shared.present(.externalPlaceSelection)
            } else if PresentationService.shared.activeSheet == .externalPlaceSelection {
                PresentationService.shared.dismiss()
            }
        }
    }

    /// Whether showing no places found alert (reads from PresentationService).
    var isShowingNoPlacesFound: Bool {
        get {
            guard let sheet = PresentationService.shared.activeSheet else { return false }
            if case .noPlacesFound = sheet { return true }
            return false
        }
        set {
            if newValue {
                PresentationService.shared.present(.noPlacesFound(contentUrl: noPlacesFoundContentUrl))
            } else if case .noPlacesFound = PresentationService.shared.activeSheet {
                PresentationService.shared.dismiss()
            }
        }
    }

    /// Content URL when no places were found
    @Published var noPlacesFoundContentUrl: String = ""

    // MARK: - Published Properties - Place Flags

    /// Place flags by place ID
    @Published var placeFlags: [String: PlaceFlag] = [:]

    // MARK: - Private State

    private var currentProcessingUrl: String? = nil
    private var recentlyProcessedURLs: Set<String> = []

    private var currentExternalPage: Int = 0
    private let externalPlacesPerPage: Int = 8
    var allExternalPlaceIds: [String] = []
    private var loadedExternalPlaceIds: [String] = []

    /// Track whether we've already prefetched metadata to avoid duplicate calls
    private var prefetchedMetadataForSession: Set<String> = []

    // MARK: - Dependencies

    private let userService: UserService
    private weak var userSession: UserSession?

    // MARK: - Callbacks for Cross-Cutting Concerns

    /// Callback to refresh external places after import (wired by parent ViewModel).
    var onRefreshExternalPlaces: (() -> Void)?

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

    /// Initializes the external content view model with required dependencies.
    init(userService: UserService, userSession: UserSession) {
        self.userService = userService
        self.userSession = userSession
    }

    // MARK: - Nearby Filter

    /// Toggles the nearby filter between Recent (paginated) and Nearby (client-side filtered) modes.
    func toggleNearbyFilter() {
        isNearbyFilterEnabled.toggle()
        lightweightExternalPlaces = []
        totalExternalPlacesCount = 0

        if isNearbyFilterEnabled {
            hasMoreExternalPlaces = false
            Task {
                await loadAllNearbyPlaces()
            }
        } else {
            allNearbyPlaces = []
            hasLoadedAllNearbyPlaces = false
            hasMoreExternalPlaces = true
            Task {
                await reloadLightweightExternalPlaces()
            }
        }
    }

    /// Disables the nearby filter if active, resetting to paginated "Recent" mode.
    func disableNearbyFilter() {
        guard isNearbyFilterEnabled else { return }
        isNearbyFilterEnabled = false
        allNearbyPlaces = []
        hasLoadedAllNearbyPlaces = false
        lightweightExternalPlaces = []
        hasMoreExternalPlaces = true
        Task {
            await reloadLightweightExternalPlaces()
        }
    }

    /// Filters displayed places to the current map viewport (instant, no network call).
    func reloadForRegionChange(newRegion: MKCoordinateRegion) {
        guard isNearbyFilterEnabled else { return }
        currentMapRegion = newRegion
        filterPlacesToViewport()
    }

    /// Fetches ALL user's external places with coordinates for client-side filtering.
    private func loadAllNearbyPlaces() async {
        guard let userId = userSession?.currentUserId else { return }

        isLoadingExternalPlaces = true
        defer { isLoadingExternalPlaces = false }

        do {
            let places = try await userService.fetchUserExternalPlaces(
                userId: userId, limit: 500, offset: 0, viewport: nil
            )
            allNearbyPlaces = places
            hasLoadedAllNearbyPlaces = true
            hasMoreExternalPlaces = false

            // Prefetch external metadata for new URLs
            let contentUrls = places.compactMap { $0.content_url }.filter { !$0.isEmpty }
            let newUrls = contentUrls.filter { !prefetchedMetadataForSession.contains($0) }
            if !newUrls.isEmpty {
                prefetchedMetadataForSession.formUnion(newUrls)
                Task {
                    await ExternalMetadataCache.shared.prefetchMetadata(for: newUrls)
                }
            }

            filterPlacesToViewport()
        } catch {
            print("❌ [ProfileExternalContentViewModel] Error loading all nearby places: \(error.localizedDescription)")
        }
    }

    /// Filters allNearbyPlaces to those within the current map viewport and updates displayed places.
    private func filterPlacesToViewport() {
        guard isNearbyFilterEnabled, let region = currentMapRegion else { return }

        let minLat = region.center.latitude - region.span.latitudeDelta / 2
        let maxLat = region.center.latitude + region.span.latitudeDelta / 2
        let minLon = region.center.longitude - region.span.longitudeDelta / 2
        let maxLon = region.center.longitude + region.span.longitudeDelta / 2

        let filtered = allNearbyPlaces.filter { place in
            guard let lat = place.latitude, let lon = place.longitude else { return false }
            return lat >= minLat && lat <= maxLat && lon >= minLon && lon <= maxLon
        }

        lightweightExternalPlaces = filtered
        totalExternalPlacesCount = filtered.count
    }

    // MARK: - External Places Loading

    /// Loads initial external places.
    func loadInitialExternalPlaces() async {
        guard let userId = userSession?.currentUserId else {
            print("⚠️ [ProfileExternalContentViewModel] Cannot load initial external places: no user ID")
            return
        }

        // Don't reload if already loading or if we have data
        guard !isLoadingExternalPlaces && lightweightExternalPlaces.isEmpty else {
            return
        }

        isLoadingExternalPlaces = true

        defer {
            isLoadingExternalPlaces = false
        }

        do {
            // Fetch first page and total count in parallel
            async let placesTask = userService.fetchUserExternalPlaces(userId: userId, limit: 8, offset: 0, viewport: nil)
            async let countTask = userService.getNumberExternalPlaces(forUserId: userId, viewport: nil)

            let lightweightPlaces = try await placesTask
            let totalCount = (try? await countTask) ?? 0

            // Prefetch external metadata (non-blocking) - only for URLs not already prefetched
            let contentUrls = lightweightPlaces.compactMap { $0.content_url }.filter { !$0.isEmpty }
            let newUrls = contentUrls.filter { !prefetchedMetadataForSession.contains($0) }
            if !newUrls.isEmpty {
                prefetchedMetadataForSession.formUnion(newUrls)
                Task {
                    await ExternalMetadataCache.shared.prefetchMetadata(for: newUrls)
                }
            }

            // Deduplicate by place_id (safety net in case SQL returns duplicates)
            var seenIds = Set<String>()
            let uniquePlaces = lightweightPlaces.filter { seenIds.insert($0.place_id).inserted }

            lightweightExternalPlaces = uniquePlaces
            totalExternalPlacesCount = totalCount
            hasMoreExternalPlaces = !lightweightPlaces.isEmpty && lightweightPlaces.count >= 8
        } catch {
            print("❌ [ProfileExternalContentViewModel] Error loading initial external places: \(error.localizedDescription)")
            hasMoreExternalPlaces = false
        }
    }

    /// Loads more external places (pagination).
    func loadMoreExternalPlaces() async {
        guard let userId = userSession?.currentUserId else {
            print("⚠️ [ProfileExternalContentViewModel] Cannot load more external places: no user ID")
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
            let lightweightPlaces = try await userService.fetchUserExternalPlaces(userId: userId, limit: 8, offset: offset, viewport: nil)

            // Prefetch external metadata (non-blocking) - only for URLs not already prefetched
            let contentUrls = lightweightPlaces.compactMap { $0.content_url }.filter { !$0.isEmpty }
            let newUrls = contentUrls.filter { !prefetchedMetadataForSession.contains($0) }
            if !newUrls.isEmpty {
                prefetchedMetadataForSession.formUnion(newUrls)
                Task {
                    await ExternalMetadataCache.shared.prefetchMetadata(for: newUrls)
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
            print("❌ [ProfileExternalContentViewModel] Error loading more external places: \(error.localizedDescription)")
            hasMoreExternalPlaces = false
        }
    }

    /// Reloads lightweight external places from database.
    func reloadLightweightExternalPlaces() async {
        if isNearbyFilterEnabled {
            await loadAllNearbyPlaces()
            return
        }

        guard let userId = userSession?.currentUserId else {
            print("⚠️ [ProfileExternalContentViewModel] Cannot reload external places: no user ID")
            return
        }

        isLoadingExternalPlaces = true

        do {
            async let placesTask = userService.fetchUserExternalPlaces(userId: userId, limit: 8, offset: 0, viewport: nil)
            async let countTask = userService.getNumberExternalPlaces(forUserId: userId, viewport: nil)

            let lightweightPlaces = try await placesTask
            let totalCount = (try? await countTask) ?? 0

            // Deduplicate by place_id (safety net in case SQL returns duplicates)
            var seenIds = Set<String>()
            let uniquePlaces = lightweightPlaces.filter { seenIds.insert($0.place_id).inserted }

            lightweightExternalPlaces = uniquePlaces
            totalExternalPlacesCount = totalCount
            hasMoreExternalPlaces = !lightweightPlaces.isEmpty && lightweightPlaces.count >= 8
        } catch {
            print("❌ [ProfileExternalContentViewModel] Error reloading external places: \(error.localizedDescription)")
        }

        isLoadingExternalPlaces = false
    }

    /// Refreshes external places after import.
    func refreshExternalPlacesAfterImport() {
        Task {
            await reloadLightweightExternalPlaces()
        }
    }

    // MARK: - Place Flagging

    /// Flags a place.
    func flagPlace(for placeId: String, flagType: PlaceFlagType, contentUrl: String? = nil, userComment: String? = nil) {
        guard let userId = userSession?.currentUserId else { return }

        let flag = PlaceFlag(
            placeId: placeId,
            userId: userId,
            flagType: flagType,
            contentUrl: contentUrl,
            userComment: userComment
        )

        placeFlags[placeId] = flag

        userService.savePlaceFlag(flag: flag) { [weak self] success, error in
            if !success {
                print("❌ [ProfileExternalContentViewModel] Error flagging place: \(error?.localizedDescription ?? "unknown")")
                DispatchQueue.main.async {
                    self?.placeFlags.removeValue(forKey: placeId)
                }
            }
        }
    }

    /// Loads a place flag.
    func loadPlaceFlag(for placeId: String) {
        guard let userId = userSession?.currentUserId else { return }

        userService.hasUserFlaggedPlace(userId: userId, placeId: placeId) { [weak self] flag, error in
            DispatchQueue.main.async {
                if let flag = flag {
                    self?.placeFlags[placeId] = flag
                }
            }
        }
    }

    /// Removes a place flag.
    func removePlaceFlag(for placeId: String) {
        guard let userId = userSession?.currentUserId else { return }

        let removedFlag = placeFlags.removeValue(forKey: placeId)

        userService.deletePlaceFlag(userId: userId, placeId: placeId) { [weak self] success, error in
            if !success {
                print("❌ [ProfileExternalContentViewModel] Error removing place flag: \(error?.localizedDescription ?? "unknown")")
                DispatchQueue.main.async {
                    if let flag = removedFlag {
                        self?.placeFlags[placeId] = flag
                    }
                }
            }
        }
    }

    /// Gets a place flag.
    func getPlaceFlag(for placeId: String) -> PlaceFlag? {
        return placeFlags[placeId]
    }

    /// Checks if a place has been flagged.
    func hasFlaggedPlace(placeId: String) -> Bool {
        return placeFlags[placeId] != nil
    }

    /// Submits a flag for content where no place could be identified.
    func submitNoPlacesFoundFlag(contentUrl: String, userComment: String) -> Bool {
        guard getCurrentUserId?() != nil else { return false }
        let tempPlaceId = "no_place_found_\(UUID().uuidString)"
        flagPlace(for: tempPlaceId, flagType: .unableToIdentify, contentUrl: contentUrl, userComment: userComment)
        return true
    }

    // MARK: - External Video Access

    /// Checks if user has external videos for a place using cached data.
    func hasExternalVideos(for placeId: String) -> Bool {
        return userExternalPlaces.values.contains { $0.placeId == placeId && $0.url != nil && !$0.url!.isEmpty }
    }

    /// Gets external place for a place ID.
    func getExternalPlace(for placeId: String) -> ExternalPlace? {
        return userExternalPlaces.values.first { $0.placeId == placeId }
    }

    /// Gets the first external thumbnail URL for a place.
    func getFirstExternalThumbnailURL(for placeId: String) -> String? {
        guard let externalPlace = userExternalPlaces.values.first(where: { $0.placeId == placeId && $0.url != nil }),
              let url = externalPlace.url,
              let metadata = ExternalMetadataCache.shared.getCachedMetadata(for: url) else {
            return nil
        }
        return metadata.thumbnailURL
    }

    // MARK: - Import State

    /// Clears import error.
    func clearImportError() {
        importError = nil
    }

    /// Removes a place from local external state.
    func removeFromLocalExternalState(placeId: String) {
        lightweightExternalPlaces.removeAll { $0.place_id == placeId }
        allNearbyPlaces.removeAll { $0.place_id == placeId }
        allExternalPlaceIds.removeAll { $0 == placeId }
        loadedExternalPlaceIds.removeAll { $0 == placeId }

        if totalExternalPlacesCount > 0 {
            totalExternalPlacesCount -= 1
        }
    }

    // MARK: - Fetch User External Places (for dictionary)

    /// Populates the userExternalPlaces dictionary for external place deletion and quick lookups.
    func fetchUserExternalPlaces() async {
        guard let userId = userSession?.currentUserId else {
            print("❌ [ProfileExternalContentViewModel] No user ID available for fetching external places")
            return
        }

        do {
            let externalPlaces = try await userService.fetchAllUserExternalPlaces(userId: userId)

            var placesDict: [String: ExternalPlace] = [:]
            for place in externalPlaces {
                placesDict[place.id] = place
            }

            userExternalPlaces = placesDict

            // Prefetch external metadata - only for URLs not already prefetched
            let contentUrls = externalPlaces.compactMap { $0.url }.filter { !$0.isEmpty }
            let newUrls = contentUrls.filter { !prefetchedMetadataForSession.contains($0) }
            if !newUrls.isEmpty {
                prefetchedMetadataForSession.formUnion(newUrls)
                Task {
                    await ExternalMetadataCache.shared.prefetchMetadata(for: newUrls)
                }
            }
        } catch {
            print("❌ [ProfileExternalContentViewModel] Error fetching external places: \(error.localizedDescription)")
        }
    }

    // MARK: - External Places Image Loading

    /// Ensures an external thumbnail is cached for display.
    func ensureExternalThumbnailCached(for placeId: String) {
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

        // Try external thumbnails first
        do {
            let urlMap = try await SupabaseUserService.shared.fetchExternalPlaceURLs(placeIds: Array(remaining), userId: userId)

            for placeId in remaining {
                guard let url = urlMap[placeId], !url.isEmpty else { continue }
                guard hasPlaceImage?(placeId) != true else { continue }

                guard let video = await ExternalMetadataCache.shared.getMetadata(for: url) else { continue }
                let thumbnailURL = video.thumbnailURL
                guard !thumbnailURL.isEmpty else { continue }

                loadRemoteImageAsPlaceImage(placeId: placeId, imageURL: thumbnailURL)
            }
        } catch {
            print("❌ [ProfileExternalContentViewModel] Error fetching external thumbnails: \(error.localizedDescription)")
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
            print("❌ [ProfileExternalContentViewModel] Error fetching regular review images: \(error.localizedDescription)")
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
            print("❌ [ProfileExternalContentViewModel] Error fetching external review images: \(error.localizedDescription)")
        }
    }

    /// Loads an image from a remote URL and stores it via callback.
    private func loadRemoteImageAsPlaceImage(placeId: String, imageURL: String) {
        if hasPlaceImage?(placeId) == true {
            return
        }

        guard let url = URL(string: imageURL) else {
            print("❌ [ProfileExternalContentViewModel] Invalid image URL for place \(placeId): \(imageURL)")
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ [ProfileExternalContentViewModel] Error loading image for \(placeId): \(error.localizedDescription)")
                } else if let data = data, let image = UIImage(data: data) {
                    self?.onPlaceImageLoaded?(placeId, image)
                } else {
                    print("⚠️ [ProfileExternalContentViewModel] No image data returned for place \(placeId)")
                }
            }
        }.resume()
    }

    /// Loads an image from URL asynchronously.
    private func loadImageFromURL(imageUrl: String, placeId: String) async {
        guard let url = URL(string: imageUrl) else {
            print("❌ [ProfileExternalContentViewModel] Invalid image URL for place \(placeId): \(imageUrl)")
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
            print("❌ [ProfileExternalContentViewModel] Error loading image for \(placeId): \(error.localizedDescription)")
        }
    }

    /// Loads external thumbnail as place image.
    func loadExternalThumbnailAsPlaceImage(placeId: String, thumbnailURL: String) async {
        guard let url = URL(string: thumbnailURL) else {
            print("❌ [ProfileExternalContentViewModel] Invalid thumbnail URL for place \(placeId): \(thumbnailURL)")
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                await MainActor.run {
                    self.onPlaceImageLoaded?(placeId, image)
                }
            } else {
                print("⚠️ [ProfileExternalContentViewModel] No image data returned for external thumbnail \(placeId)")
            }
        } catch {
            print("❌ [ProfileExternalContentViewModel] Error loading external thumbnail for \(placeId): \(error.localizedDescription)")
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

    /// Gets external_place_id for a video URL at a specific place.
    func getExternalPlaceId(for placeId: String, videoUrl: String) async -> String? {
        guard let userId = getCurrentUserId?() else {
            return nil
        }

        do {
            let urlPairs = try await userService.fetchExternalPlaceURLs(placeId: placeId, userId: userId)
            return urlPairs.first(where: { $0.url == videoUrl })?.id
        } catch {
            print("❌ [ProfileExternalContentViewModel] Error fetching external_place_id: \(error)")
            return nil
        }
    }

    /// Gets external videos for a place using cached metadata.
    func getExternalVideosSync(for placeId: String) -> [ExternalVideo] {
        print("🎬 [ProfileExternalContentViewModel] getExternalVideosSync for placeId: \(placeId)")
        print("  - userExternalPlaces count: \(userExternalPlaces.count)")

        let matchingPlaces = userExternalPlaces.values.filter { $0.placeId == placeId && $0.url != nil && !$0.url!.isEmpty }
        print("  - matchingPlaces for this placeId: \(matchingPlaces.count)")
        let currentUserId = getCurrentUserId?()

        var videos: [ExternalVideo] = []
        for externalPlace in matchingPlaces {
            guard let url = externalPlace.url else { continue }

            if var video = ExternalMetadataCache.shared.getCachedMetadata(for: url) {
                video.savedByUserId = currentUserId
                video.externalPlaceId = externalPlace.id
                videos.append(video)
            } else {
                let videoId = extractVideoIdFromURL(url) ?? UUID().uuidString
                let detectedContentType = url.contains("/photo/") ? "photo" : "video"
                var basicVideo = ExternalVideo(
                    videoID: videoId,
                    url: url,
                    title: nil,
                    caption: nil,
                    embedHTML: "",
                    thumbnailURL: "",
                    author: ExternalVideoAuthor(displayName: "", url: "", username: ""),
                    hashtags: [],
                    createdAt: ISO8601DateFormatter().string(from: Date()),
                    contentType: detectedContentType
                )
                basicVideo.savedByUserId = currentUserId
                basicVideo.externalPlaceId = externalPlace.id
                videos.append(basicVideo)
            }
        }

        print("  - Returning \(videos.count) videos")
        return videos
    }

    /// Extracts video ID from URL.
    private func extractVideoIdFromURL(_ url: String) -> String? {
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

    /// Resets all external content data (used during logout).
    func resetAllData() {
        lightweightExternalPlaces.removeAll()
        totalExternalPlacesCount = 0
        userExternalPlaces.removeAll()
        isLoadingExternalPlaces = false
        isLoadingMoreExternalPlaces = false
        hasMoreExternalPlaces = true
        isNearbyFilterEnabled = false
        currentMapRegion = nil
        allNearbyPlaces = []
        hasLoadedAllNearbyPlaces = false
        isProcessingContent = false
        isWaitingForPlaceDetail = false
        importError = nil
        importedPlaces.removeAll()
        isShowingPlaceSelection = false
        isShowingNoPlacesFound = false
        noPlacesFoundContentUrl = ""
        placeFlags.removeAll()
        currentProcessingUrl = nil
        recentlyProcessedURLs.removeAll()
        hasMoreExternalPlaces = true
        currentExternalPage = 0
        allExternalPlaceIds.removeAll()
        loadedExternalPlaceIds.removeAll()
        prefetchedMetadataForSession.removeAll()
    }

    // MARK: - External Place Deletion

    /// Deletes an external place with completion handler.
    func deleteExternalPlace(_ place: DetailPlace, completion: @escaping (Bool) -> Void) {
        guard let userId = getCurrentUserId?() else {
            completion(false)
            return
        }

        let placeId = place.id.uuidString

        // Optimistic update: Remove from all local collections immediately
        removeFromLocalExternalStateWithMapUpdate(placeId: placeId, userId: userId)

        // Call backend to delete the external place
        userService.deleteExternalPlace(userId: userId, placeId: placeId) { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ [ProfileExternalContentViewModel] Error deleting external place: \(error.localizedDescription)")
                    completion(false)
                } else {
                    completion(true)
                }
            }
        }
    }

    /// Deletes an external place using LightweightPlace (for popup views).
    func deleteExternalPlace(_ place: LightweightPlace) {
        guard let userId = getCurrentUserId?() else { return }

        let placeId = place.place_id

        // Optimistic update: Remove from all local collections immediately
        removeFromLocalExternalStateWithMapUpdate(placeId: placeId, userId: userId)

        // Persist deletion to backend
        userService.deleteExternalPlace(userId: userId, placeId: placeId) { error in
            if let error = error {
                print("❌ [ProfileExternalContentViewModel] Error deleting external place: \(error.localizedDescription)")
            }
        }
    }

    /// Removes external place from all local state collections and updates map.
    private func removeFromLocalExternalStateWithMapUpdate(placeId: String, userId: String) {
        // Remove from external content state
        removeFromLocalExternalState(placeId: placeId)
        userExternalPlaces.removeValue(forKey: placeId)

        // Cross-cutting map concerns via callbacks
        onPlaceSaversUpdate?(placeId, userId, false)
        onPlacesRemove?(placeId)
        onAnnotationPlacesRecalculate?()
    }

    /// Updates an external place association by external place ID.
    func updateExternalPlaceById(externalPlaceId: String, newPlaceId: String, newPlaceName: String) async {
        guard let userId = getCurrentUserId?() else {
            print("❌ [ProfileExternalContentViewModel] Cannot update external place: missing userId")
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
                content_url: original.content_url,
                added_by_user_id: original.added_by_user_id,
                added_by_name: original.added_by_name,
                added_by_photo_url: original.added_by_photo_url
            )
            lightweightExternalPlaces[index] = updatedPlace
        }

        // Update ID tracking
        if let old = oldPlaceId {
            allExternalPlaceIds.removeAll { $0 == old }
        }
        if !allExternalPlaceIds.contains(newPlaceId) {
            allExternalPlaceIds.append(newPlaceId)
        }

        // Persist to backend
        do {
            try await userService.updateExternalPlaceAssociation(
                externalPlaceId: externalPlaceId,
                newPlaceId: newPlaceId,
                userId: userId
            )
            print("✅ [ProfileExternalContentViewModel] Updated external place to \(newPlaceId)")
        } catch {
            print("❌ [ProfileExternalContentViewModel] Error updating external place: \(error.localizedDescription)")
            // Revert optimistic update on failure
            onRefreshExternalPlaces?()
        }
    }

    // MARK: - Content URL Processing

    /// Processes a shared content URL and extracts place information.
    func processSharedContentURL(
        _ urlString: String,
        contentService: ExternalContentService,
        selectedPlaceVM: SelectedPlaceViewModel,
        placeVM: DetailPlaceViewModel,
        deepLinkManager: DeepLinkManager?,
        deepLinkViewModel: DeepLinkViewModel?
    ) async -> Bool {
        // Check if this URL was recently processed
        if recentlyProcessedURLs.contains(urlString) {
            print("⚠️ [ProfileExternalContentViewModel] URL already processed recently, skipping: \(urlString)")
            return false
        }

        // Check if already processing
        if isProcessingContent {
            print("⚠️ [ProfileExternalContentViewModel] Already processing a content URL, skipping: \(urlString)")
            return false
        }

        // Mark as processing and add to recently processed
        await MainActor.run {
            isProcessingContent = true
            recentlyProcessedURLs.insert(urlString)
            currentProcessingUrl = urlString
        }

        let result = await contentService.processURL(urlString)

        // Clear from recently processed after 30 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) {
            self.recentlyProcessedURLs.remove(urlString)
        }

        switch result {
        case .success(let detailPlaces):
            importError = nil

            await handleSuccessfulContentProcessing(
                detailPlaces: detailPlaces,
                urlString: urlString,
                selectedPlaceVM: selectedPlaceVM,
                placeVM: placeVM,
                deepLinkManager: deepLinkManager
            )

            return true

        case .failure(let error):
            print("❌ [ProfileExternalContentViewModel] Content processing failed: \(error.localizedDescription)")

            await MainActor.run {
                setImportErrorMessage(from: error)
                isProcessingContent = false
                deepLinkManager?.isProcessingDeepLink = false
                currentProcessingUrl = nil
            }

            return false
        }
    }

    /// Handles successful content URL processing with extracted places.
    private func handleSuccessfulContentProcessing(
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

    /// Handles a single place result from content processing.
    private func handleSinglePlace(
        _ detailPlace: DetailPlace,
        urlString: String,
        selectedPlaceVM: SelectedPlaceViewModel,
        placeVM: DetailPlaceViewModel,
        deepLinkManager: DeepLinkManager?
    ) {
        // Validate place has a name
        if detailPlace.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            print("❌ [ProfileExternalContentViewModel] Single place found but has no name")
            noPlacesFoundContentUrl = urlString
            isShowingNoPlacesFound = true
            isProcessingContent = false
            deepLinkManager?.isProcessingDeepLink = false
            return
        }

        placeVM.places[detailPlace.id.uuidString] = detailPlace
        placeVM.calculateAnnotationPlaces()

        // Show confirmation prompt instead of navigating directly
        PresentationService.shared.present(
            .importPlaceConfirmation(placeId: detailPlace.id.uuidString, contentUrl: urlString)
        )

        // Clear loading states immediately
        isProcessingContent = false
        isWaitingForPlaceDetail = false
        deepLinkManager?.isProcessingDeepLink = false
        currentProcessingUrl = nil
    }

    /// Handles multiple places result from content processing.
    private func handleMultiplePlacesFromProcessing(
        _ detailPlaces: [DetailPlace],
        urlString: String,
        placeVM: DetailPlaceViewModel,
        deepLinkManager: DeepLinkManager?
    ) {
        print("🎯 [ProfileExternalContentViewModel] MULTIPLE PLACES DETECTED: \(detailPlaces.count) places")

        // Validate all places have names
        let validPlaces = detailPlaces.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        for place in validPlaces {
            print("   ✓ \(place.name)")
        }

        if validPlaces.isEmpty {
            print("❌ [ProfileExternalContentViewModel] No valid places found after filtering")
            noPlacesFoundContentUrl = urlString
            isShowingNoPlacesFound = true
            isProcessingContent = false
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
        isProcessingContent = false
        isWaitingForPlaceDetail = false
        deepLinkManager?.isProcessingDeepLink = false
    }

    /// Handles the case when no places are found from content processing.
    private func handleNoPlacesFound(urlString: String, deepLinkManager: DeepLinkManager?) {
        print("❌ [ProfileExternalContentViewModel] No places found")
        noPlacesFoundContentUrl = urlString
        isShowingNoPlacesFound = true
        isProcessingContent = false
        isWaitingForPlaceDetail = false
        deepLinkManager?.isProcessingDeepLink = false
    }

    /// Sets a user-friendly error message based on the error type.
    private func setImportErrorMessage(from error: Error) {
        if error.localizedDescription.contains("network") || error.localizedDescription.contains("Internet") {
            importError = "Please check your internet connection and try again"
        } else if error.localizedDescription.contains("invalid") || error.localizedDescription.contains("URL") {
            importError = "This doesn't appear to be a valid URL"
        } else {
            importError = "We couldn't find any places in this video. Try sharing a different video that shows specific locations"
        }
    }

    /// Clears place selection state and refreshes external places.
    func clearPlaceSelection() {
        importedPlaces = []
        isShowingPlaceSelection = false
        currentProcessingUrl = nil

        // Refresh external places list after clearing selection
        onRefreshExternalPlaces?()
    }

    /// Clears the no places found state.
    func clearNoPlacesFound(deepLinkManager: DeepLinkManager?, deepLinkViewModel: DeepLinkViewModel?) {
        isShowingNoPlacesFound = false
        noPlacesFoundContentUrl = ""
        // Ensure processing states are cleared when user closes the view
        isProcessingContent = false
        isWaitingForPlaceDetail = false
        deepLinkManager?.isProcessingDeepLink = false
        deepLinkViewModel?.isProcessingDeepLink = false
    }

    /// Called when the place selection view appears.
    func placeSelectionViewAppeared(deepLinkManager: DeepLinkManager?, deepLinkViewModel: DeepLinkViewModel?) {
        isWaitingForPlaceDetail = false
        isProcessingContent = false
        deepLinkManager?.isProcessingDeepLink = false
        deepLinkViewModel?.isProcessingDeepLink = false
    }

    /// Handles multiple places received from notifications.
    func handleMultiplePlaces(_ places: [DetailPlace]) {
        print("🎯 [ProfileExternalContentViewModel] Received \(places.count) places")
        for place in places {
            print("   - \(place.name) (ID: \(place.id))")
        }

        importedPlaces = places
        isShowingPlaceSelection = true

        print("🎯 [ProfileExternalContentViewModel] Set isShowingPlaceSelection = true")
    }

    /// Handles multiple places notification with content URL.
    func handleMultiplePlacesNotification(places: [DetailPlace], contentUrl: String?) {
        print("🎯 [ProfileExternalContentViewModel] Handling multiple places notification with content URL")
        if let contentUrl = contentUrl {
            currentProcessingUrl = contentUrl
        }
        handleMultiplePlaces(places)
    }

    /// Handles content notification and processes the URL.
    func handleContentNotification(
        url: String,
        contentService: ExternalContentService,
        selectedPlaceVM: SelectedPlaceViewModel,
        placeVM: DetailPlaceViewModel,
        deepLinkManager: DeepLinkManager?,
        deepLinkViewModel: DeepLinkViewModel?
    ) {
        Task {
            await processSharedContentURL(
                url,
                contentService: contentService,
                selectedPlaceVM: selectedPlaceVM,
                placeVM: placeVM,
                deepLinkManager: deepLinkManager,
                deepLinkViewModel: deepLinkViewModel
            )
        }
    }

    /// Checks UserDefaults for a pending content URL and processes it.
    func checkPendingContentURL(
        contentService: ExternalContentService,
        selectedPlaceVM: SelectedPlaceViewModel,
        placeVM: DetailPlaceViewModel,
        deepLinkManager: DeepLinkManager?,
        deepLinkViewModel: DeepLinkViewModel?
    ) {
        if let pendingURL = UserDefaults.standard.string(forKey: "pendingTikTokURL") {
            Task {
                await processSharedContentURL(
                    pendingURL,
                    contentService: contentService,
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
