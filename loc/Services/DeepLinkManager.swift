//
//  DeepLinkManager.swift
//  loc
//
//  Created by Cursor Assistant on [current date]
//

import Foundation
import SwiftUI
import FirebaseFirestore

class DeepLinkManager: ObservableObject {
    @Published var pendingPlace: ShareablePlace?
    @Published var isProcessingDeepLink = false
    
    private let placeService: PlaceService
    private let selectedPlaceViewModel: SelectedPlaceViewModel
    private let tikTokService: TikTokService
    private let detailPlaceViewModel: DetailPlaceViewModel
    private let tikTokAuthService: TikTokAuthService
    
    init(placeService: PlaceService, selectedPlaceViewModel: SelectedPlaceViewModel, tikTokService: TikTokService = TikTokService(), detailPlaceViewModel: DetailPlaceViewModel, tikTokAuthService: TikTokAuthService) {
        self.placeService = placeService
        self.selectedPlaceViewModel = selectedPlaceViewModel
        self.tikTokService = tikTokService
        self.detailPlaceViewModel = detailPlaceViewModel
        self.tikTokAuthService = tikTokAuthService
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
        case "share":
            if url.path == "/tiktok" {
                await handleTikTokDeepLink(url)
            } else {
                print("❌ Unknown share path: \(url.path)")
            }
        case "auth":
            if url.path.hasPrefix("/tiktok") {
                await handleTikTokAuthDeepLink(url)
            } else {
                print("❌ Unknown auth path: \(url.path)")
            }
        default:
            print("❌ Unknown deep link host: \(url.host ?? "nil")")
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
        
        await MainActor.run {
            isProcessingDeepLink = true
        }
        
        await loadPlaceDetails(shareablePlace)
        
        await MainActor.run {
            isProcessingDeepLink = false
        }
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
        
        await MainActor.run {
            isProcessingDeepLink = false
        }
    }
    
    private func processTikTokURL(_ urlString: String) async {
        print("🔄 [DeepLinkManager] Calling TikTok backend for URL: \(urlString)")
        let result = await tikTokService.processTikTokURL(urlString)
        
        switch result {
        case .success(let detailPlace):
            print("✅ [DeepLinkManager] Backend response received")
            print("📍 Place name: \(detailPlace.name)")
            print("🏢 Address: \(detailPlace.address ?? "No address")")
            print("🏙️ City: \(detailPlace.city ?? "No city")")
            print("📌 Coordinates: (\(detailPlace.coordinate?.latitude ?? 0), \(detailPlace.coordinate?.longitude ?? 0))")
            print("🆔 Place ID: \(detailPlace.id)")
            
            // NOTE: Place saving is handled by backend during URL processing
            // Frontend only displays the place, does not save to Firestore
            print("✅ [DeepLinkManager] Place processed, navigating to details")
            
            await navigateToPlace(detailPlace)
            
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
    
    func hasPendingPlace() -> Bool {
        return pendingPlace != nil
    }
    
    // MARK: - TikTok Auth Deep Link Handling
    
    private func handleTikTokAuthDeepLink(_ url: URL) async {
        print("🎵 TikTokAuth: Handling auth deep link: \(url)")
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            print("❌ TikTokAuth: Failed to parse URL components")
            return
        }
        
        switch url.path {
        case "/tiktok/success":
            await handleTikTokAuthSuccess(components: components)
        case "/tiktok/failure":
            await handleTikTokAuthFailure(components: components)
        default:
            print("❌ TikTokAuth: Unknown auth path: \(url.path)")
        }
    }
    
    private func handleTikTokAuthSuccess(components: URLComponents) async {
        print("🎵 TikTokAuth: Handling success deep link")
        print("🎵 TikTokAuth: Query items: \(components.queryItems ?? [])")
        
        guard let connectionId = components.queryItems?.first(where: { $0.name == "connection_id" })?.value else {
            print("❌ TikTokAuth: Missing connection_id in success URL")
            await showTikTokAuthError("Missing connection information")
            return
        }
        
        print("🎵 TikTokAuth: Found connection_id: \(connectionId)")
        
        await MainActor.run {
            isProcessingDeepLink = true
        }
        
        let success = await tikTokAuthService.completeTikTokConnection(connectionId: connectionId)
        
        await MainActor.run {
            isProcessingDeepLink = false
            
            if success {
                print("✅ TikTokAuth: Connection completed successfully")
                showTikTokAuthSuccess("TikTok account connected!")
            } else {
                print("❌ TikTokAuth: Failed to complete connection")
                showTikTokAuthError("Failed to complete TikTok connection")
            }
        }
    }
    
    private func handleTikTokAuthFailure(components: URLComponents) async {
        print("🎵 TikTokAuth: Handling failure deep link")
        
        let error = components.queryItems?.first(where: { $0.name == "error" })?.value ?? "unknown"
        print("❌ TikTokAuth: OAuth failed with error: \(error)")
        
        await MainActor.run {
            let message: String
            switch error {
            case "access_denied":
                message = "TikTok authorization was cancelled"
            case "invalid_state":
                message = "Security error. Please try again."
            default:
                message = "Failed to connect TikTok account"
            }
            
            showTikTokAuthError(message)
        }
    }
    
    private func showTikTokAuthSuccess(_ message: String) {
        // Post notification that can be picked up by the UI
        NotificationCenter.default.post(
            name: Notification.Name("TikTokAuthSuccess"),
            object: nil,
            userInfo: ["message": message]
        )
    }
    
    private func showTikTokAuthError(_ message: String) {
        // Post notification that can be picked up by the UI
        NotificationCenter.default.post(
            name: Notification.Name("TikTokAuthError"),
            object: nil,
            userInfo: ["message": message]
        )
    }
} 