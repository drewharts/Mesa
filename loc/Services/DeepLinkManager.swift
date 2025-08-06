//
//  DeepLinkManager.swift
//  loc
//
//  Created by Cursor Assistant on [current date]
//

import Foundation
import SwiftUI
import FirebaseFirestore

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
    
    // Deduplication mechanism for TikTok URLs
    private static var recentlyProcessedURLs: Set<String> = []
    private static var urlProcessingQueue = DispatchQueue(label: "url-processing", qos: .userInitiated)
    
    init(placeService: PlaceService, userService: UserService, selectedPlaceViewModel: SelectedPlaceViewModel, tikTokService: TikTokService = TikTokService(), detailPlaceViewModel: DetailPlaceViewModel) {
        self.placeService = placeService
        self.userService = userService
        self.selectedPlaceViewModel = selectedPlaceViewModel
        self.tikTokService = tikTokService
        self.detailPlaceViewModel = detailPlaceViewModel
    }
    
    // MARK: - Deep Link Processing
    
    func processDeepLink(_ url: URL) async {
        print("🔗 Processing deep link: \(url)")
        
        guard url.scheme == "loc" else {
            print("❌ Invalid URL scheme: \(url.scheme ?? "nil")")
            return
        }
        
        switch url.host {
        case "place":
            await handlePlaceDeepLink(url)
        case "list":
            await handleListDeepLink(url)
        case "share":
            if url.path == "/tiktok" {
                await handleTikTokDeepLink(url)
            } else {
                print("❌ Unknown share path: \(url.path)")
            }
        default:
            print("❌ Unknown deep link host: \(url.host ?? "nil")")
        }
    }
    
    private func handleListDeepLink(_ url: URL) async {
        print("🔗 Starting to handle list deep link: \(url)")
        
        guard let shareableList = ShareableList.from(url: url) else {
            print("❌ Failed to parse shareable list from URL: \(url)")
            return
        }
        
        print("✅ Successfully parsed shareable list: \(shareableList.name)")
        
        userService.fetchUserLists(userId: shareableList.userId) { [weak self] lists, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Error fetching user lists: \(error.localizedDescription)")
                return
            }
            
            guard let lists = lists, !lists.isEmpty else {
                print("❌ No lists found for user: \(shareableList.userId)")
                return
            }
            
            if let initialIndex = lists.firstIndex(where: { $0.id.uuidString == shareableList.id }) {
                DispatchQueue.main.async {
                    self.pendingList = (lists: lists, initialIndex: initialIndex)
                }
            } else {
                print("❌ Shared list not found in user's lists.")
            }
        }
    }
    
    private func handlePlaceDeepLink(_ url: URL) async {
        print("🔗 Starting to handle place deep link: \(url)")
        
        guard let shareablePlace = ShareablePlace.from(url: url) else {
            print("❌ Failed to parse shareable place from URL: \(url)")
            print("❌ URL components: scheme=\(url.scheme ?? "nil"), host=\(url.host ?? "nil"), path=\(url.path)")
            return
        }
        
        print("✅ Successfully parsed shareable place: \(shareablePlace.name)")
        print("✅ Place details: id=\(shareablePlace.id), address=\(shareablePlace.address ?? "nil"), city=\(shareablePlace.city ?? "nil")")
        
        // Place deep links should navigate immediately without processing UI
        await loadPlaceDetails(shareablePlace)
    }
    
    private func handleTikTokDeepLink(_ url: URL) async {
        print("🎵 Starting to handle TikTok deep link: \(url)")
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let urlItem = components.queryItems?.first(where: { $0.name == "url" }),
              let tiktokURLString = urlItem.value else {
            print("❌ Failed to extract TikTok URL from deep link")
            return
        }
        
        print("🎵 Processing TikTok URL: \(tiktokURLString)")
        
        
        await MainActor.run {
            isProcessingDeepLink = true
        }
        
        await processTikTokURL(tiktokURLString)
        
        // The isProcessingDeepLink state will be managed by the ProfileViewModel
        // based on the presentation of the single place or multiple place selection view.
        // await MainActor.run {
        //     isProcessingDeepLink = false
        // }
    }
    
    private func processTikTokURL(_ urlString: String) async {
        // Check for duplicate processing
        let shouldProcess = await withCheckedContinuation { continuation in
            Self.urlProcessingQueue.async {
                if Self.recentlyProcessedURLs.contains(urlString) {
                    print("⏭️ [DeepLinkManager] Skipping duplicate TikTok URL: \(urlString)")
                    continuation.resume(returning: false)
                } else {
                    print("🔄 [DeepLinkManager] Processing TikTok URL: \(urlString)")
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
        
        // If duplicate, show brief processing message then return
        guard shouldProcess else { 
            print("💫 [DeepLinkManager] Showing brief processing message for duplicate URL")
            // Show processing UI for a brief moment to give user feedback
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            return 
        }
        
        print("🔄 [DeepLinkManager] Calling TikTok backend for URL: \(urlString)")
        let result = await tikTokService.processTikTokURL(urlString)
        
        switch result {
        case .success(let detailPlaces):
            print("✅ [DeepLinkManager] Backend response received")
            
            if detailPlaces.isEmpty {
                print("❌ [DeepLinkManager] No places found in TikTok video")
                
                // Show user-friendly message
                await MainActor.run {
                    let message = "We couldn't figure out what place is associated with this video."
                    self.onNoLocationFound?(message)
                }
                return
            }
            
            if detailPlaces.count == 1 {
                // Single place - navigate directly
                let detailPlace = detailPlaces[0]
            print("📍 Place name: \(detailPlace.name)")
            print("🏢 Address: \(detailPlace.address ?? "No address")")
            print("🏙️ City: \(detailPlace.city ?? "No city")")
            print("📌 Coordinates: (\(detailPlace.coordinate?.latitude ?? 0), \(detailPlace.coordinate?.longitude ?? 0))")
            print("🆔 Place ID: \(detailPlace.id)")
            
            // NOTE: Place saving is handled by backend during URL processing
            // Frontend only displays the place, does not save to Firestore
            print("✅ [DeepLinkManager] Place processed, navigating to details")
            
            await navigateToPlace(detailPlace)
            } else {
                // Multiple places - let ProfileViewModel handle the selection
                print("📍 Multiple places found (\(detailPlaces.count))")
                
                // Set the places in ProfileViewModel to show the selection screen
                await MainActor.run {
                    // Find ProfileViewModel from the environment or view hierarchy
                    // For now, we'll set the places directly and trigger the selection screen
                    print("🎯 [DeepLinkManager] Setting multiple places for selection")
                    print("Places: \(detailPlaces.map { "\($0.name) (ID: \($0.id))" }.joined(separator: ", "))")
                    
                    // We need to trigger the ProfileViewModel's multiple place handling
                    // This should be done by calling the ProfileViewModel method
                    NotificationCenter.default.post(
                        name: NSNotification.Name("TikTokMultiplePlacesFound"),
                        object: nil,
                        userInfo: ["places": detailPlaces]
                    )
                }
            }
            
        case .failure(let error):
            print("❌ [DeepLinkManager] Failed to process TikTok URL: \(error.localizedDescription)")
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
        return await withCheckedContinuation { continuation in
            placeService.fetchPlace(withId: placeId) { result in
                switch result {
                case .success(let place):
                    continuation.resume(returning: place)
                case .failure(let error):
                    print("❌ Error finding place by ID: \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    // MARK: - DetailPlace Creation
    
    private func createDetailPlace(from shareablePlace: ShareablePlace) -> DetailPlace {
        var detailPlace = DetailPlace()
        detailPlace.id = UUID(uuidString: shareablePlace.id) ?? UUID()
        detailPlace.name = shareablePlace.name
        detailPlace.address = shareablePlace.address
        detailPlace.city = shareablePlace.city
        detailPlace.mapboxId = shareablePlace.mapboxId
        
        if let lat = shareablePlace.latitude, let lng = shareablePlace.longitude {
            detailPlace.coordinate = GeoPoint(latitude: lat, longitude: lng)
        }
        
        return detailPlace
    }
    
    // MARK: - Navigation
    
    private func navigateToPlace(_ place: DetailPlace) async {
        print("🏪 DeepLinkManager: Starting navigation to place: \(place.name)")
        print("📍 Place coordinate: \(place.coordinate?.latitude ?? 0), \(place.coordinate?.longitude ?? 0)")
        print("🆔 Place ID: \(place.id)")
        
        await MainActor.run {
            print("🗺️ DeepLinkManager: Adding place to map")
            detailPlaceViewModel.places[place.id.uuidString] = place
            
            print("🎯 DeepLinkManager: Setting selectedPlace in ViewModel")
            selectedPlaceViewModel.selectedPlace = place
            
            print("📱 DeepLinkManager: Presenting detail sheet")
            selectedPlaceViewModel.isDetailSheetPresented = true
            
            print("🧹 DeepLinkManager: Clearing pending place")
            pendingPlace = nil
            
            print("✅ DeepLinkManager: Navigation completed successfully")
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