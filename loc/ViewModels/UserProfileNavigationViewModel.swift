//
//  UserProfileNavigationViewModel.swift
//  loc
//
//  Single Responsibility: Manages navigation state for external user profiles.
//  This ViewModel handles only which user profile to show and navigation triggers.
//

import Foundation
import SwiftUI

/// Manages navigation state for external user profiles.
/// Single Responsibility: Only handles navigation - which profile to show, when to show it.
@MainActor
class UserProfileNavigationViewModel: ObservableObject {
    // MARK: - Navigation State

    /// The currently selected user for external profile navigation
    @Published var selectedUser: ProfileData?

    /// Controls whether the external profile detail view is presented
    @Published var isUserDetailPresented = false

    /// Tracks if navigation originated from place detail (for state restoration)
    @Published var navigatedFromPlaceDetail: Bool = false

    /// Controls whether to navigate to the user's own profile (instead of external profile)
    @Published var shouldNavigateToOwnProfile = false

    // MARK: - Deep Link List Popup State

    /// The list ID to auto-open after navigating to profile (for deep links)
    private(set) var pendingListIdToOpen: String?

    // MARK: - Dependencies

    private let userService: UserService
    private let userSession: UserSession
    private var notificationObserver: NSObjectProtocol?
    private var listNotificationObserver: NSObjectProtocol?

    // MARK: - Initialization

    init(userService: UserService, userSession: UserSession) {
        self.userService = userService
        self.userSession = userSession
        setupNotificationObserver()
    }

    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = listNotificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Notification Observer

    /// Sets up observers for follow and list notification navigation.
    private func setupNotificationObserver() {
        notificationObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NavigateToUserProfileFromNotification"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userId = notification.userInfo?["userId"] as? String,
                  let currentUserId = self.userSession.currentUserId else {
                return
            }
            self.fetchAndSelectUser(userId: userId, currentUserId: currentUserId)
        }

        listNotificationObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NavigateToListFromNotification"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let listId = notification.userInfo?["listId"] as? String else {
                return
            }
            Task { @MainActor in
                await self.navigateToListFromNotification(listId: listId)
            }
        }
    }

    // MARK: - Public Methods

    /// Sets up user data and optionally triggers programmatic navigation.
    /// - Parameters:
    ///   - user: The user profile data to select
    ///   - currentUserId: The current user's ID for following status checks
    ///   - shouldPresent: If true, triggers programmatic navigation via isUserDetailPresented.
    ///     Set to false when NavigationLink is handling navigation to prevent double navigation.
    ///   - fromPlaceDetail: If true, indicates navigation originated from place detail (for state restoration)
    func selectUser(_ user: ProfileData, currentUserId: String, shouldPresent: Bool = true, fromPlaceDetail: Bool = false) {
        // Navigate to own profile if user taps themselves
        if user.id == currentUserId {
            self.shouldNavigateToOwnProfile = true
            return
        }

        // Existing external profile navigation
        self.selectedUser = user
        self.navigatedFromPlaceDetail = fromPlaceDetail
        if shouldPresent {
            self.isUserDetailPresented = true
        }
    }

    /// Clears the own profile navigation state after navigation is triggered.
    func clearOwnProfileNavigation() {
        shouldNavigateToOwnProfile = false
    }

    /// Fetches a user by ID and navigates to their profile.
    func fetchAndSelectUser(userId: String, currentUserId: String) {
        userService.fetchUserById(userId: userId) { [weak self] result in
            switch result {
            case .success(let profileData):
                self?.selectUser(profileData, currentUserId: currentUserId)
            case .failure(let error):
                print("Error fetching user profile: \(error.localizedDescription)")
            }
        }
    }

    /// Navigates to a user's profile and queues a specific list to auto-open.
    /// Called by DeepLinkManager when handling list deep links.
    func navigateToUserWithList(userId: String, listId: String, currentUserId: String) {
        self.pendingListIdToOpen = listId

        userService.fetchUserById(userId: userId) { [weak self] result in
            switch result {
            case .success(let profileData):
                self?.selectUser(profileData, currentUserId: currentUserId)
            case .failure(let error):
                print("Error fetching user profile: \(error.localizedDescription)")
                self?.clearPendingListState()
            }
        }
    }

    /// Resolves the list owner and navigates to their profile with the list auto-opened.
    func navigateToListFromNotification(listId: String) async {
        guard let currentUserId = userSession.currentUserId else { return }

        do {
            let ownerId = try await userService.fetchListOwnerId(listId: listId)
            navigateToUserWithList(userId: ownerId, listId: listId, currentUserId: currentUserId)
        } catch {
            print("❌ [UserProfileNavigationVM] Error fetching list owner: \(error.localizedDescription)")
        }
    }

    /// Clears the pending list state (called after list is shown or on error).
    func clearPendingListState() {
        pendingListIdToOpen = nil
    }

    /// Clears all navigation state (e.g., when user dismisses profile).
    func clearSelection() {
        selectedUser = nil
        isUserDetailPresented = false
        navigatedFromPlaceDetail = false
        pendingListIdToOpen = nil
    }

    // MARK: - Logout Cleanup

    /// Clears all user-related cached data - MUST be called on logout to prevent data leakage.
    func clearAllUserData() {
        print("🗑️ [UserProfileNavigationViewModel] Clearing all user data for security")
        clearSelection()
        shouldNavigateToOwnProfile = false
        print("✅ [UserProfileNavigationViewModel] All user data cleared")
    }
}
