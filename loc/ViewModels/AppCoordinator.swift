//
//  AppCoordinator.swift
//  loc
//
//  Created by Cursor on 11/13/25.
//

import SwiftUI
import Combine

/// Coordinates high-level app state and navigation
/// Only contains cross-cutting concerns that truly need to be global
@MainActor
class AppCoordinator: ObservableObject {
    // MARK: - Navigation State
    @Published var isShowingPlaceDetail = false
    @Published var isShowingProfile = false
    @Published var isShowingUserProfile = false
    
    // MARK: - UI State
    @Published var isSearchExpanded = false
    @Published var selectedPlace: Place?
    @Published var selectedUserId: String?
    
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
}

