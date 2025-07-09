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
    
    init(placeService: PlaceService, selectedPlaceViewModel: SelectedPlaceViewModel, tikTokService: TikTokService = TikTokService()) {
        self.placeService = placeService
        self.selectedPlaceViewModel = selectedPlaceViewModel
        self.tikTokService = tikTokService
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
        let result = await tikTokService.processTikTokURL(urlString)
        
        switch result {
        case .success(let response):
            let place = createPlaceFromTikTokResponse(response)
            await navigateToPlace(place)
            
        case .failure(let error):
            print("❌ Failed to process TikTok URL: \(error.localizedDescription)")
        }
    }
    
    private func createPlaceFromTikTokResponse(_ response: TikTokProcessorResponse) -> DetailPlace {
        return tikTokService.createPlaceFromTikTok(response)
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
        print("🏪 Navigating to place: \(place.name)")
        await MainActor.run {
            selectedPlaceViewModel.selectedPlace = place
            selectedPlaceViewModel.isDetailSheetPresented = true
            pendingPlace = nil
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
} 