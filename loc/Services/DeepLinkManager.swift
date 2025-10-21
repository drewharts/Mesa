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
        guard url.scheme == "loc" else {
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
            }
        default:
            break
        }
    }
    
    private func handleListDeepLink(_ url: URL) async {
        guard let shareableList = ShareableList.from(url: url) else {
            return
        }
        
        userService.fetchUserLists(userId: shareableList.userId) { [weak self] lists, error in
            guard let self = self else { return }
            
            if let error = error {
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
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let urlItem = components.queryItems?.first(where: { $0.name == "url" }),
              let tiktokURLString = urlItem.value else {
            return
        }
        
        await MainActor.run {
            isProcessingDeepLink = true
        }
        
        await processTikTokURL(tiktokURLString)
        
        // The isProcessingDeepLink state will be managed by the ProfileViewModel
        // based on the presentation of the single place or multiple place selection view.
    }
    
    private func processTikTokURL(_ urlString: String) async {
        // Check for duplicate processing
        let shouldProcess = await withCheckedContinuation { continuation in
            Self.urlProcessingQueue.async {
                if Self.recentlyProcessedURLs.contains(urlString) {
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
        
        // If duplicate, show brief processing message then return
        guard shouldProcess else { 
            // Show processing UI for a brief moment to give user feedback
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            return 
        }
        
        let result = await tikTokService.processTikTokURL(urlString)
        
        switch result {
        case .success(let detailPlaces):
            if detailPlaces.isEmpty {
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

            // Check if the place has valid location data
            let hasValidLocation = detailPlace.coordinate?.latitude != 0.0 &&
                                   detailPlace.coordinate?.longitude != 0.0 &&
                                   detailPlace.coordinate?.latitude != nil &&
                                   detailPlace.coordinate?.longitude != nil

            if !hasValidLocation {
                await MainActor.run {
                    let message = "We couldn't find a valid location for this video. The video may not be associated with a specific place."
                    self.onNoLocationFound?(message)
                }
                return
            }

            // NOTE: Place saving is handled by backend during URL processing
            // Frontend only displays the place, does not save to Firestore
            await navigateToPlace(detailPlace)
            } else {
                // Multiple places - let ProfileViewModel handle the selection
                await MainActor.run {
                    // We need to trigger the ProfileViewModel's multiple place handling
                    NotificationCenter.default.post(
                        name: NSNotification.Name("TikTokMultiplePlacesFound"),
                        object: nil,
                        userInfo: ["places": detailPlaces]
                    )
                }
            }
            
        case .failure(_):
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
    
    private func navigateToPlace(_ place: DetailPlace) async {
        await MainActor.run {
            detailPlaceViewModel.places[place.id.uuidString] = place
            // Animate map to place location when navigating from deep link
            selectedPlaceViewModel.selectPlace(place, shouldAnimateMap: true)
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