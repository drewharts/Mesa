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
    
    private let placeService: PlaceService
    private let userService: UserService
    private let selectedPlaceViewModel: SelectedPlaceViewModel
    private let tikTokService: TikTokService
    private let detailPlaceViewModel: DetailPlaceViewModel
    private weak var profileViewModel: ProfileViewModel?
    
    // Deduplication mechanism for TikTok URLs
    private static var recentlyProcessedURLs: Set<String> = []
    private static var urlProcessingQueue = DispatchQueue(label: "url-processing", qos: .userInitiated)
    
    // Store TikTok URL during processing to create external_place entry
    private var currentProcessingTikTokUrl: String?
    
    init(placeService: PlaceService, userService: UserService, selectedPlaceViewModel: SelectedPlaceViewModel, tikTokService: TikTokService = TikTokService(), detailPlaceViewModel: DetailPlaceViewModel, profileViewModel: ProfileViewModel? = nil) {
        self.placeService = placeService
        self.userService = userService
        self.selectedPlaceViewModel = selectedPlaceViewModel
        self.tikTokService = tikTokService
        self.detailPlaceViewModel = detailPlaceViewModel
        self.profileViewModel = profileViewModel
    }
    
    /// Set the ProfileViewModel reference (called after ProfileViewModel is created)
    func setProfileViewModel(_ profileViewModel: ProfileViewModel) {
        self.profileViewModel = profileViewModel
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
        case "tiktok-shared":
            print("🎵 [DeepLinkManager] host is 'tiktok-shared', routing to handleTikTokFromExtension")
            await handleTikTokFromExtension()
        case "share":
            print("📤 [DeepLinkManager] host is 'share', checking path...")
            if url.path == "/tiktok" {
                print("🎵 [DeepLinkManager] Path is '/tiktok', routing to handleTikTokDeepLink")
                await handleTikTokDeepLink(url)
            } else if url.path == "/list" {
                print("📋 [DeepLinkManager] Path is '/list', routing to handleListShareDeepLink")
                await handleListShareDeepLink(url)
            } else {
                print("❌ [DeepLinkManager] Path is '\(url.path)', not '/tiktok' or '/list'")
            }
        default:
            print("❌ [DeepLinkManager] Unknown host: \(url.host ?? "nil")")
            break
        }
    }
    
    private func handleListDeepLink(_ url: URL) async {
        guard let shareableList = ShareableList.from(url: url) else {
            return
        }
        
        userService.fetchUserLists(userId: shareableList.userId) { [weak self] lists, error in
            guard let self = self else { return }
            
            if error != nil {
                return
            }
            
            guard let lists = lists, !lists.isEmpty else {
                return
            }
            
            if let initialIndex = lists.firstIndex(where: { $0.id.uuidString == shareableList.id }) {
                DispatchQueue.main.async {
                    self.pendingList = (lists: lists, initialIndex: initialIndex)
                }
            }
        }
    }
    
    private func handlePlaceDeepLink(_ url: URL) async {
        guard let shareablePlace = ShareablePlace.from(url: url) else {
            return
        }
        
        // Place deep links should navigate immediately without processing UI
        await loadPlaceDetails(shareablePlace)
    }
    
    private func handleTikTokDeepLink(_ url: URL) async {
        print("🔗 [DeepLinkManager] handleTikTokDeepLink called with URL: \(url)")

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let urlItem = components.queryItems?.first(where: { $0.name == "url" }),
              let tiktokURLString = urlItem.value else {
            print("❌ [DeepLinkManager] Failed to extract TikTok URL from deep link")
            return
        }

        print("✅ [DeepLinkManager] Extracted TikTok URL: \(tiktokURLString)")
        isProcessingDeepLink = true
        await processTikTokURL(tiktokURLString)
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
    
    private func handleTikTokFromExtension() async {
        print("🎵 [DeepLinkManager] handleTikTokFromExtension called")
        
        // Get TikTok URL from App Group
        let shared = UserDefaults(suiteName: "group.com.mesa.loc")
        guard let tiktokURLString = shared?.string(forKey: "sharedTikTokURL"),
              let tiktokURL = URL(string: tiktokURLString) else {
            print("❌ [DeepLinkManager] No TikTok URL found in App Group")
            return
        }
        
        print("✅ [DeepLinkManager] Found TikTok URL: \(tiktokURLString)")
        
        // Clear the stored URL
        shared?.removeObject(forKey: "sharedTikTokURL")
        
        // Process the TikTok URL
        await processTikTokURL(tiktokURLString)
    }
    
    private func processTikTokURL(_ urlString: String) async {
        print("🎬 [DeepLinkManager] Starting processTikTokURL for: \(urlString)")
        
        // Store URL for later use when creating external_place entry
        currentProcessingTikTokUrl = urlString
        
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
            currentProcessingTikTokUrl = nil
            return 
        }
        
        print("📞 [DeepLinkManager] Calling TikTokService...")
        let result = await tikTokService.processTikTokURL(urlString)
        print("📨 [DeepLinkManager] TikTokService returned with result")
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
                currentProcessingTikTokUrl = nil
                return
            }
            
            if detailPlaces.count == 1 {
                let place = detailPlaces[0]
                print("🧭 [DeepLinkManager] Navigating to place: \(place.name)")
                
                // Navigate directly - backend returns full place details
                await navigateToPlace(place, tikTokUrl: urlString)
            } else {
                // Multiple places - let ProfileViewModel handle the selection
                await MainActor.run {
                    // We need to trigger the ProfileViewModel's multiple place handling
                    NotificationCenter.default.post(
                        name: NSNotification.Name("TikTokMultiplePlacesFound"),
                        object: nil,
                        userInfo: ["places": detailPlaces, "tikTokUrl": urlString]
                    )
                }
                // Keep URL stored for when user selects a place
            }
            
        case .failure(let error):
            print("❌ [DeepLinkManager] Result is .failure: \(error.localizedDescription)")
            currentProcessingTikTokUrl = nil
            break
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
    
    private func navigateToPlace(_ place: DetailPlace, tikTokUrl: String? = nil) async {
        print("📍 [DeepLinkManager] navigateToPlace called for: \(place.name)")
        await MainActor.run {
            print("📱 [DeepLinkManager] On main thread, setting up place detail view")
            detailPlaceViewModel.places[place.id.uuidString] = place
            
            // selectPlaceAndFetchDetails will:
            // 1. Set selectedPlace (triggers didSet)
            // 2. Load reviews AND TikToks for the place
            // 3. Animate map to place location
            print("🔄 [DeepLinkManager] Calling selectPlaceAndFetchDetails - this will load reviews & TikToks")
            selectedPlaceViewModel.selectPlaceAndFetchDetails(place, shouldAnimateMap: true)
            selectedPlaceViewModel.isDetailSheetPresented = true
            print("✅ [DeepLinkManager] Place detail sheet presented")
            pendingPlace = nil
        }
        
        // Create external_place entry if we have a TikTok URL
        if let tikTokUrl = tikTokUrl ?? currentProcessingTikTokUrl {
            print("💾 [DeepLinkManager] Creating external_place entry for TikTok: \(tikTokUrl)")
            if let profileViewModel = profileViewModel {
                let success = await profileViewModel.createExternalPlaceEntry(
                    placeId: place.id.uuidString,
                    tikTokUrl: tikTokUrl,
                    place: place
                )
                if success {
                    print("✅ [DeepLinkManager] Successfully created external_place entry")
                } else {
                    print("❌ [DeepLinkManager] Failed to create external_place entry")
                }
            } else {
                print("⚠️ [DeepLinkManager] ProfileViewModel not available, cannot create external_place entry")
            }
            currentProcessingTikTokUrl = nil
        }
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
