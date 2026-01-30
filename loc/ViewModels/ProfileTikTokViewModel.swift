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

    /// Whether showing place selection sheet
    @Published var isShowingPlaceSelection: Bool = false

    /// Whether showing no places found alert
    @Published var isShowingNoPlacesFound: Bool = false

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

    // MARK: - Dependencies

    private let userService: UserService
    private weak var userSession: UserSession?

    // MARK: - Callbacks for Cross-Cutting Concerns

    /// Callback to refresh TikTok places after import (wired by parent ViewModel).
    var onRefreshTikTokPlaces: (() -> Void)?

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

            // Prefetch TikTok metadata (non-blocking)
            let tiktokUrls = lightweightPlaces.compactMap { $0.tiktok_url }.filter { !$0.isEmpty }
            if !tiktokUrls.isEmpty {
                Task {
                    await TikTokMetadataCache.shared.prefetchMetadata(for: tiktokUrls)
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

            // Prefetch TikTok metadata (non-blocking)
            let tiktokUrls = lightweightPlaces.compactMap { $0.tiktok_url }.filter { !$0.isEmpty }
            if !tiktokUrls.isEmpty {
                Task {
                    await TikTokMetadataCache.shared.prefetchMetadata(for: tiktokUrls)
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

    /// Gets TikTok videos for a place using cached metadata.
    func getTikTokVideosSync(for placeId: String) -> [TikTokVideo] {
        let matchingPlaces = userExternalPlaces.values.filter { $0.placeId == placeId && $0.url != nil && !$0.url!.isEmpty }
        let currentUserId = userSession?.currentUserId

        var videos: [TikTokVideo] = []
        for externalPlace in matchingPlaces {
            guard let url = externalPlace.url else { continue }

            if var tikTokVideo = TikTokMetadataCache.shared.getCachedMetadata(for: url) {
                tikTokVideo.savedByUserId = currentUserId
                tikTokVideo.externalPlaceId = externalPlace.id
                videos.append(tikTokVideo)
            }
        }
        return videos
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

            // Prefetch TikTok metadata
            let tiktokUrls = externalPlaces.compactMap { $0.url }.filter { !$0.isEmpty }
            if !tiktokUrls.isEmpty {
                Task {
                    await TikTokMetadataCache.shared.prefetchMetadata(for: tiktokUrls)
                }
            }
        } catch {
            print("❌ [ProfileTikTokViewModel] Error fetching external places: \(error.localizedDescription)")
        }
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
