//
//  DeepLinkManager.swift
//  loc
//
//  Created by Cursor Assistant on [current date]
//

import Foundation
import SwiftUI
import CoreLocation

@MainActor
class DeepLinkManager: ObservableObject {
    @Published var pendingPlace: ShareablePlace?
    @Published var pendingList: (lists: [PlaceList], initialIndex: Int)?
    @Published var isProcessingDeepLink = false
    
    // Callback for showing no location alerts
    var onNoLocationFound: ((String) -> Void)?
    
    // MARK: - Dependencies
    private let placeService: PlaceService
    private let userService: UserService
    private let selectedPlaceViewModel: SelectedPlaceViewModel
    private let externalContentService: ExternalContentService
    private let detailPlaceViewModel: DetailPlaceViewModel
    
    // Weak references to avoid retain cycles (set after init due to circular dependencies)
    private weak var profileViewModel: ProfileViewModel?
    private weak var userProfileNavigationViewModel: UserProfileNavigationViewModel?
    private weak var userSession: UserSession?
    
    // MARK: - External Content Processing State
    nonisolated(unsafe) private static var recentlyProcessedURLs: Set<String> = []
    private static var urlProcessingQueue = DispatchQueue(label: "url-processing", qos: .userInitiated)
    private var currentProcessingURL: String?
    
    // MARK: - Initialization
    init(
        placeService: PlaceService,
        userService: UserService,
        selectedPlaceViewModel: SelectedPlaceViewModel,
        externalContentService: ExternalContentService = ExternalContentService(),
        detailPlaceViewModel: DetailPlaceViewModel,
        profileViewModel: ProfileViewModel? = nil
    ) {
        self.placeService = placeService
        self.userService = userService
        self.selectedPlaceViewModel = selectedPlaceViewModel
        self.externalContentService = externalContentService
        self.detailPlaceViewModel = detailPlaceViewModel
        self.profileViewModel = profileViewModel
    }
    
    // MARK: - Dependency Injection (post-init due to circular dependencies)
    
    func setProfileViewModel(_ profileViewModel: ProfileViewModel) {
        self.profileViewModel = profileViewModel
    }
    
    func setUserProfileNavigationViewModel(_ userProfileNavigationViewModel: UserProfileNavigationViewModel) {
        self.userProfileNavigationViewModel = userProfileNavigationViewModel
    }
    
    func setUserSession(_ userSession: UserSession) {
        self.userSession = userSession
    }
    
    // MARK: - Deep Link Processing
    
    func processDeepLink(_ url: URL) async {
        print("🔗 [DeepLinkManager] processDeepLink called with URL: \(url)")
        print("🔗 [DeepLinkManager] scheme: \(url.scheme ?? "nil"), host: \(url.host ?? "nil"), path: \(url.path)")
        
        guard url.scheme == "loc" else {
            print("❌ [DeepLinkManager] Invalid scheme, expected 'loc'")
            return
        }
        
        switch url.host {
        case "place":
            print("📍 [DeepLinkManager] Routing to handlePlaceDeepLink")
            await handlePlaceDeepLink(url)
        case "list":
            print("📋 [DeepLinkManager] Routing to handleListDeepLink")
            await handleListDeepLink(url)
        case "profile":
            print("👤 [DeepLinkManager] Routing to handleProfileDeepLink")
            await handleProfileDeepLink(url)
        case "tiktok-shared":
            print("📤 [DeepLinkManager] host is 'tiktok-shared', routing to handleContentFromExtension")
            await handleContentFromExtension()
        case "share":
            print("📤 [DeepLinkManager] host is 'share', checking path...")
            if url.path == "/content" || url.path == "/tiktok" {
                print("📤 [DeepLinkManager] Path is '\(url.path)', routing to handleExternalContentDeepLink")
                await handleExternalContentDeepLink(url)
            } else if url.path == "/list" {
                print("📋 [DeepLinkManager] Path is '/list', routing to handleListShareDeepLink")
                await handleListShareDeepLink(url)
            } else {
                print("❌ [DeepLinkManager] Path is '\(url.path)', not '/content', '/tiktok', or '/list'")
            }
        default:
            print("❌ [DeepLinkManager] Unknown host: \(url.host ?? "nil")")
            break
        }
    }
    
    private func handleListDeepLink(_ url: URL) async {
        guard let shareableList = ShareableList.from(url: url) else {
            print("❌ [DeepLinkManager] Failed to parse ShareableList from URL")
            return
        }

        guard let userProfileNavigationViewModel = userProfileNavigationViewModel else {
            print("❌ [DeepLinkManager] UserProfileNavigationViewModel not set, cannot navigate to profile")
            return
        }

        guard let currentUserId = userSession?.currentUserId else {
            print("❌ [DeepLinkManager] No current user ID available")
            return
        }

        // Delegate to UserProfileNavigationViewModel - it owns the profile navigation responsibility
        userProfileNavigationViewModel.navigateToUserWithList(
            userId: shareableList.userId,
            listId: shareableList.id,
            currentUserId: currentUserId
        )
    }

    private func handleProfileDeepLink(_ url: URL) async {
        guard let shareableProfile = ShareableProfile.from(url: url) else {
            print("❌ [DeepLinkManager] Failed to parse ShareableProfile from URL")
            return
        }

        guard let userProfileNavigationViewModel = userProfileNavigationViewModel else {
            print("❌ [DeepLinkManager] UserProfileNavigationViewModel not set, cannot navigate to profile")
            return
        }

        guard let currentUserId = userSession?.currentUserId else {
            print("❌ [DeepLinkManager] No current user ID available")
            return
        }

        print("👤 [DeepLinkManager] Navigating to profile: \(shareableProfile.id)")

        // Navigate to profile using UserProfileNavigationViewModel
        userProfileNavigationViewModel.fetchAndSelectUser(userId: shareableProfile.id, currentUserId: currentUserId)
    }

    private func handlePlaceDeepLink(_ url: URL) async {
        guard let shareablePlace = ShareablePlace.from(url: url) else {
            return
        }
        
        // Place deep links should navigate immediately without processing UI
        await loadPlaceDetails(shareablePlace)
    }
    
    private func handleExternalContentDeepLink(_ url: URL) async {
        print("🔗 [DeepLinkManager] handleExternalContentDeepLink called with URL: \(url)")

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let urlItem = components.queryItems?.first(where: { $0.name == "url" }),
              let contentURLString = urlItem.value else {
            print("❌ [DeepLinkManager] Failed to extract content URL from deep link")
            return
        }

        print("✅ [DeepLinkManager] Extracted content URL: \(contentURLString)")
        isProcessingDeepLink = true
        await processExternalContentURL(contentURLString)
        isProcessingDeepLink = false
    }

    private func handleListShareDeepLink(_ url: URL) async {
        print("🔗 [DeepLinkManager] handleListShareDeepLink called with URL: \(url)")

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let textItem = components.queryItems?.first(where: { $0.name == "text" }),
              let sharedText = textItem.value else {
            print("❌ [DeepLinkManager] Failed to extract shared text from deep link")
            return
        }

        print("✅ [DeepLinkManager] Extracted shared text: \(sharedText)")

        // Show a confirmation that the list was shared
        await MainActor.run {
            // Post a notification that can be handled by any view controller to show a toast/alert
            NotificationCenter.default.post(
                name: NSNotification.Name("ListSharedViaExtension"),
                object: nil,
                userInfo: ["message": "Your list has been shared successfully!"]
            )
        }
    }
    
    private func handleContentFromExtension() async {
        print("🎵 [DeepLinkManager] handleContentFromExtension called")
        
        // Check App Group first (preferred method) - check both old and new keys for backward compat
        if let sharedDefaults = UserDefaults(suiteName: "group.com.drewhartsfield.mesa"),
           let contentURLString = sharedDefaults.string(forKey: "sharedTikTokURL") ?? sharedDefaults.string(forKey: "sharedContentURL") {
            print("✅ [DeepLinkManager] Found content URL in App Group: \(contentURLString)")
            sharedDefaults.removeObject(forKey: "sharedTikTokURL")
            sharedDefaults.removeObject(forKey: "sharedContentURL")
            sharedDefaults.synchronize()
            await processExternalContentURL(contentURLString)
            return
        }

        // Fallback: Check standard UserDefaults - check both old and new keys for backward compat
        if let contentURLString = UserDefaults.standard.string(forKey: "sharedTikTokURL") ?? UserDefaults.standard.string(forKey: "sharedContentURL") {
            print("✅ [DeepLinkManager] Found content URL in standard UserDefaults: \(contentURLString)")
            UserDefaults.standard.removeObject(forKey: "sharedTikTokURL")
            UserDefaults.standard.removeObject(forKey: "sharedContentURL")
            UserDefaults.standard.synchronize()
            await processExternalContentURL(contentURLString)
            return
        }

        print("❌ [DeepLinkManager] No content URL found in App Group or standard UserDefaults")
    }
    
    private func processExternalContentURL(_ urlString: String) async {
        print("🎬 [DeepLinkManager] Starting processExternalContentURL for: \(urlString)")
        
        // Store URL for later use when creating external_place entry
        currentProcessingURL = urlString
        
        // Check for duplicate processing
        let shouldProcess = await withCheckedContinuation { continuation in
            Self.urlProcessingQueue.async {
                if Self.recentlyProcessedURLs.contains(urlString) {
                    print("⚠️ [DeepLinkManager] Duplicate URL detected, skipping")
                    continuation.resume(returning: false)
                } else {
                    Self.recentlyProcessedURLs.insert(urlString)
                    
                    // Clean up old URLs after 30 seconds to prevent memory buildup
                    DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                        Self.urlProcessingQueue.async {
                            Self.recentlyProcessedURLs.remove(urlString)
                        }
                    }
                    
                    continuation.resume(returning: true)
                }
            }
        }
        
        guard shouldProcess else { 
            print("⏭️ [DeepLinkManager] Skipping duplicate URL")
            currentProcessingURL = nil
            return 
        }
        
        print("📞 [DeepLinkManager] Calling ExternalContentService...")
        let result = await externalContentService.processURL(urlString)
        print("📨 [DeepLinkManager] ExternalContentService returned with result")
        print("🔍 [DeepLinkManager] Processing result...")
        
        switch result {
        case .success(let detailPlaces):
            print("✅ [DeepLinkManager] Result is .success with \(detailPlaces.count) place(s)")
            if detailPlaces.isEmpty {
                // Show user-friendly message
                await MainActor.run {
                    let message = "We couldn't figure out what place is associated with this video."
                    self.onNoLocationFound?(message)
                }
                currentProcessingURL = nil
                return
            }
            
            if detailPlaces.count == 1 {
                let place = detailPlaces[0]
                print("🧭 [DeepLinkManager] Navigating to place: \(place.name)")
                
                // Navigate directly - backend returns full place details
                await navigateToPlace(place, contentUrl: urlString)
            } else {
                // Multiple places - let ProfileViewModel handle the selection
                await MainActor.run {
                    // We need to trigger the ProfileViewModel's multiple place handling
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ExternalContentMultiplePlacesFound"),
                        object: nil,
                        userInfo: ["places": detailPlaces, "contentUrl": urlString]
                    )
                }
                // Keep URL stored for when user selects a place
            }
            
        case .failure(let error):
            print("❌ [DeepLinkManager] Result is .failure: \(error.localizedDescription)")
            await MainActor.run {
                if let externalContentVM = self.profileViewModel?.externalContentViewModel {
                    externalContentVM.noPlacesFoundContentUrl = urlString
                    externalContentVM.isShowingNoPlacesFound = true
                } else {
                    self.onNoLocationFound?("We couldn't identify a place in this video.")
                }
            }
            currentProcessingURL = nil
        }
    }
    
    private func loadPlaceDetails(_ shareablePlace: ShareablePlace) async {
        if let existingPlace = await findExistingPlace(shareablePlace) {
            await navigateToPlace(existingPlace)
            return
        }
        
        let detailPlace = createDetailPlace(from: shareablePlace)
        await navigateToPlace(detailPlace)
    }
    
    // MARK: - Place Lookup
    
    private func findExistingPlace(_ shareablePlace: ShareablePlace) async -> DetailPlace? {
        // Try to find by mapboxId first
        if let mapboxId = shareablePlace.mapboxId {
            if let place = await searchPlaceByMapboxId(mapboxId) {
                return place
            }
        }
        
        // Try to find by placeId
        if let place = await searchPlaceById(shareablePlace.id) {
            return place
        }
        
        return nil
    }
    
    private func searchPlaceByMapboxId(_ mapboxId: String) async -> DetailPlace? {
        return await withCheckedContinuation { continuation in
            placeService.findPlace(mapboxId: mapboxId) { place, error in
                if let error = error {
                    print("❌ Error finding place by mapboxId: \(error)")
                }
                continuation.resume(returning: place)
            }
        }
    }
    
    private func searchPlaceById(_ placeId: String) async -> DetailPlace? {
        do {
            print("🔍 [DeepLinkManager] Querying Supabase for place: \(placeId)")
            let place = try await SupabasePlaceService.shared.fetchPlaceDetails(placeId: placeId)
            print("✅ [DeepLinkManager] Successfully fetched place from Supabase: \(place?.name ?? "nil")")
            return place
        } catch {
            print("❌ [DeepLinkManager] Error fetching place by ID: \(error)")
            return nil
        }
    }
    
    // MARK: - DetailPlace Creation
    
    private func createDetailPlace(from shareablePlace: ShareablePlace) -> DetailPlace {
        var detailPlace = DetailPlace()
        
        // CRITICAL: ShareablePlace.id must be a valid UUID
        // Never create a new UUID - this will orphan the place from the original
        guard let placeId = UUID(uuidString: shareablePlace.id) else {
            // Return empty DetailPlace with error - caller should handle this
            var errorPlace = DetailPlace()
            errorPlace.id = UUID() // Temporary, but this shouldn't be saved
            errorPlace.name = "Error loading place"
            return errorPlace
        }
        detailPlace.id = placeId
        detailPlace.name = shareablePlace.name
        detailPlace.address = shareablePlace.address
        detailPlace.city = shareablePlace.city
        detailPlace.mapboxId = shareablePlace.mapboxId
        
        if let lat = shareablePlace.latitude, let lng = shareablePlace.longitude {
            detailPlace.coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        
        return detailPlace
    }
    
    // MARK: - Navigation
    
    private func navigateToPlace(_ place: DetailPlace, contentUrl: String? = nil) async {
        print("📍 [DeepLinkManager] navigateToPlace called for: \(place.name)")
        await MainActor.run {
            print("📱 [DeepLinkManager] On main thread, setting up place detail view")
            detailPlaceViewModel.places[place.id.uuidString] = place

            if let contentUrl = contentUrl {
                // Import path: show confirmation prompt instead of navigating directly
                print("🔄 [DeepLinkManager] Showing import place confirmation for: \(place.name)")
                PresentationService.shared.present(
                    .importPlaceConfirmation(placeId: place.id.uuidString, contentUrl: contentUrl)
                )
            } else {
                // Regular deep link: navigate directly to place detail
                print("🔄 [DeepLinkManager] Calling selectPlaceAndFetchDetails - this will load reviews & external videos")
                selectedPlaceViewModel.selectPlaceAndFetchDetails(place, shouldAnimateMap: true)
                selectedPlaceViewModel.isDetailSheetPresented = true
            }
            print("✅ [DeepLinkManager] Place detail sheet presented")
            pendingPlace = nil
        }

        currentProcessingURL = nil
    }
    
    // MARK: - Public Methods
    
    func clearPendingPlace() {
        Task { @MainActor in
            pendingPlace = nil
        }
    }
    
    func clearPendingList() {
        Task { @MainActor in
            pendingList = nil
        }
    }
    
    func hasPendingPlace() -> Bool {
        return pendingPlace != nil
    }
    
    func hasPendingList() -> Bool {
        return pendingList != nil
    }
} 
