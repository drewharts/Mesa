//
//  DeepLinkViewModel.swift
//  loc
//
//  Created by Cursor Assistant on [current date]
//

import Foundation
import SwiftUI
import Combine
import FirebaseFirestore

class DeepLinkViewModel: ObservableObject {
    @Published var isShowingPlaceFromDeepLink = false
    @Published var deepLinkedPlace: DetailPlace?
    @Published var isProcessingDeepLink = false
    
    private let deepLinkManager: DeepLinkManager
    private let selectedPlaceViewModel: SelectedPlaceViewModel
    private var cancellables = Set<AnyCancellable>()
    
    init(deepLinkManager: DeepLinkManager, selectedPlaceViewModel: SelectedPlaceViewModel) {
        self.deepLinkManager = deepLinkManager
        self.selectedPlaceViewModel = selectedPlaceViewModel
        
        setupObservers()
    }
    
    // MARK: - Setup
    
    private func setupObservers() {
        // Observe changes in the deep link manager
        deepLinkManager.$pendingPlace
            .compactMap { $0 }
            .sink { [weak self] (shareablePlace: ShareablePlace) in
                Task { @MainActor in
                    await self?.handlePendingPlace(shareablePlace)
                }
            }
            .store(in: &cancellables)
        
        deepLinkManager.$isProcessingDeepLink
            .assign(to: &$isProcessingDeepLink)
    }
    
    // MARK: - Deep Link Handling
    
    @MainActor
    func processIncomingURL(_ url: URL) async {
        await deepLinkManager.processDeepLink(url)
    }
    
    @MainActor
    private func handlePendingPlace(_ shareablePlace: ShareablePlace) async {
        // Convert ShareablePlace to DetailPlace for the UI
        let detailPlace = convertToDetailPlace(shareablePlace)
        
        // Set the place and show it
        deepLinkedPlace = detailPlace
        isShowingPlaceFromDeepLink = true
        
        // Also update the main selected place view model
        selectedPlaceViewModel.selectedPlace = detailPlace
        selectedPlaceViewModel.isDetailSheetPresented = true
        
        // Clear pending place
        deepLinkManager.clearPendingPlace()
    }
    
    // MARK: - Conversion Methods
    
    private func convertToDetailPlace(_ shareablePlace: ShareablePlace) -> DetailPlace {
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
    
    // MARK: - UI State Management
    
    @MainActor
    func dismissDeepLinkedPlace() {
        isShowingPlaceFromDeepLink = false
        deepLinkedPlace = nil
    }
    
    func hasDeepLinkedPlace() -> Bool {
        return deepLinkedPlace != nil
    }
    
    // MARK: - Navigation Helpers
    
    @MainActor
    func navigateToDeepLinkedPlace() {
        guard let place = deepLinkedPlace else { return }
        
        // Update the main view model to show this place
        selectedPlaceViewModel.selectedPlace = place
        
        // Navigate to the place detail view
        isShowingPlaceFromDeepLink = true
    }
} 
