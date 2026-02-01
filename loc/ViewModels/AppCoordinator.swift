//
//  AppCoordinator.swift
//  loc
//
//  Created by Cursor on 11/13/25.
//

import SwiftUI
import Combine
import MapKit

/// Coordinates high-level app state and navigation
/// Only contains cross-cutting concerns that truly need to be global
@MainActor
class AppCoordinator: ObservableObject {
    // MARK: - Navigation State
    @Published var isShowingPlaceDetail = false
    @Published var isShowingProfile = false
    @Published var isShowingUserProfile = false
    
    // MARK: - UI State
    @Published var selectedPlace: Place?
    @Published var selectedUserId: String?

    // MARK: - Map State
    /// Current visible map region - updated by MapView when camera settles
    /// Used for viewport-based keyword search filtering
    @Published var currentMapRegion: MKCoordinateRegion?

    // MARK: - Keyword Results Popup Trigger
    /// Used to trigger keyword results popup from search (SearchContainerView -> MainView -> MapContainerView)
    @Published var showKeywordResultsPopup: Bool = false
    @Published var keywordForPopup: String? = nil
    @Published var keywordTypesForPopup: [String] = []

    // MARK: - Loading States
    @Published var isProcessingDeepLink = false
    @Published var isProcessingTikTok = false
    
    // MARK: - Alert State
    @Published var showAlert = false
    @Published var alertTitle = ""
    @Published var alertMessage = ""
    
    // MARK: - Methods
    func showPlace(_ place: Place) {
        selectedPlace = place
        isShowingPlaceDetail = true
    }
    
    func dismissPlaceDetail() {
        isShowingPlaceDetail = false
        // Note: Keep selectedPlace for map highlight
    }
    
    func showUserProfile(userId: String) {
        selectedUserId = userId
        isShowingUserProfile = true
    }
    
    func dismissUserProfile() {
        isShowingUserProfile = false
        selectedUserId = nil
    }
    
    func showError(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }

    /// Trigger keyword results popup from search
    /// Called by MainView when user taps "View All" in keyword search results
    func triggerKeywordResultsPopup(keyword: String, types: [String]) {
        keywordForPopup = keyword
        keywordTypesForPopup = types
        showKeywordResultsPopup = true
    }
}

