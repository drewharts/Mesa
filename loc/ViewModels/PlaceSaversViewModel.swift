//
//  PlaceSaversViewModel.swift
//  loc
//
//  Smart ViewModel for managing place savers data and navigation
//  Follows Single Responsibility: owns all business logic for "who saved this place"
//
//  Data Flow:
//  1. setPlace() is called when PlaceDetailView appears
//  2. Fetches savers from database in real-time (not relying on pre-loaded data)
//  3. Exposes savers via @Published properties
//  4. UI reacts to @Published property changes
//

import Foundation
import UIKit
import Combine

@MainActor
class PlaceSaversViewModel: ObservableObject {
    // MARK: - Published Properties (What the View Needs)
    @Published private(set) var followedSavers: [ProfileData] = []  // Users current user follows
    @Published private(set) var unfollowedSavers: [ProfileData] = []  // Users current user doesn't follow
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var error: Error?
    @Published private(set) var currentUserSaved: Bool = false
    @Published private(set) var totalSaverCount: Int = 0  // Count of all savers (excluding current user)
    @Published private(set) var totalGlobalSaveCount: Int = 0  // Total saves from ALL users (for display)
    @Published private(set) var reviewedSaverIds: Set<String> = []  // IDs of savers who left a review

    /// All savers combined (for backward compatibility)
    var savers: [ProfileData] {
        followedSavers + unfollowedSavers
    }

    // MARK: - Dependencies (Services only)
    private let userService: UserService
    private let userSession: UserSession

    /// Callback for when savers are updated - allows parent to sync with DetailPlaceViewModel if needed
    var onSaversUpdated: ((_ placeId: String, _ saverIds: [String]) -> Void)?

    // For user navigation (temporary coupling during migration)
    private weak var userProfileNavigationViewModel: UserProfileNavigationViewModel?

    private var currentPlaceId: String?
    private var fetchTask: Task<Void, Never>?

    // MARK: - Initialization
    init(userService: UserService,
         userSession: UserSession) {
        self.userService = userService
        self.userSession = userSession
    }
    
    // MARK: - Configuration
    
    /// Call this to set up the UserProfileNavigationViewModel reference for navigation
    func configure(userProfileNavigationViewModel: UserProfileNavigationViewModel) {
        self.userProfileNavigationViewModel = userProfileNavigationViewModel
    }
    
    // MARK: - Public Actions
    
    /// Updates the current place and fetches savers in real-time
    func setPlace(_ placeId: String?) {
        // Cancel any in-flight fetch
        fetchTask?.cancel()
        
        currentPlaceId = placeId
        guard let placeId = placeId else {
            resetState()
            return
        }
        
        print("🔍 [PlaceSavers] setPlace called for: \(placeId.prefix(8))...")
        
        // Fetch savers from database in real-time
        fetchSaversFromDatabase(placeId: placeId)
    }
    
    /// Handles user tap - navigates to their profile
    /// Takes dismiss closure from View (View owns presentation state)
    func selectUser(_ user: ProfileData, dismiss: @escaping () -> Void) {
        guard let currentUserId = userSession.currentUserId,
              let userProfileNavVM = userProfileNavigationViewModel else { return }

        // Dismiss sheet first (View handles this)
        dismiss()

        // Navigate after brief delay for smooth transition
        // Pass fromPlaceDetail: true so state can be restored when returning
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            userProfileNavVM.selectUser(user, currentUserId: currentUserId, fromPlaceDetail: true)
        }
    }
    
    // MARK: - Computed Properties

    /// Followed savers excluding current user (for indicator circles)
    var displayableFollowedSavers: [ProfileData] {
        guard let currentUserId = userSession.currentUserId else { return followedSavers }
        return followedSavers.filter { $0.id != currentUserId }
    }

    /// Unfollowed savers excluding current user
    var displayableUnfollowedSavers: [ProfileData] {
        guard let currentUserId = userSession.currentUserId else { return unfollowedSavers }
        return unfollowedSavers.filter { $0.id != currentUserId }
    }

    /// All savers excluding current user (for backward compatibility)
    var displayableSavers: [ProfileData] {
        displayableFollowedSavers + displayableUnfollowedSavers
    }

    /// Count of savers excluding current user (for indicator)
    var displayableSaverCount: Int {
        displayableSavers.count
    }

    /// Number of additional savers beyond visible circles (for "+X" display)
    var additionalSaverCount: Int {
        max(0, displayableSaverCount - 3)
    }

    /// Whether to show the savers indicator at all
    /// Only show if OTHER people (besides just the current user) have saved this place
    var shouldShowSaversIndicator: Bool {
        // If current user saved, need at least 2 total saves to show indicator
        // If current user didn't save, any saves will show indicator
        currentUserSaved ? totalGlobalSaveCount > 1 : totalGlobalSaveCount > 0
    }

    /// Whether the current user has reviewed this place
    var currentUserReviewed: Bool {
        guard let currentUserId = userSession.currentUserId else { return false }
        return reviewedSaverIds.contains(currentUserId)
    }

    /// Whether there are any followed savers to display (excluding current user)
    var hasFollowedSavers: Bool {
        displayableFollowedSavers.count > 0
    }

    /// Whether there are any unfollowed savers to display
    var hasUnfollowedSavers: Bool {
        displayableUnfollowedSavers.count > 0
    }
    
    /// Get first N saver IDs for profile circle display (excluding current user)
    /// Shows followed users first, then unfollowed users
    func saverIdsForDisplay(limit: Int = 3) -> [String] {
        return Array(displayableSavers.prefix(limit).map { $0.id })
    }

    /// Get first N savers (ProfileData) for profile circle display (excluding current user)
    /// Shows followed users first, then unfollowed users
    func saversForDisplay(limit: Int = 3) -> [ProfileData] {
        return Array(displayableSavers.prefix(limit))
    }
    
    // MARK: - Private Methods

    /// Fetches place savers from database in real-time.
    private func fetchSaversFromDatabase(placeId: String) {
        fetchTask = Task { [weak self] in
            guard let self else { return }
            do {
                let saverProfiles = try await self.userService.fetchPlaceSavers(
                    placeId: placeId,
                    requestingUserId: self.userSession.currentUserId
                )
                guard !Task.isCancelled else { return }
                self.applyFetchedSavers(saverProfiles, placeId: placeId)
            } catch {
                guard !Task.isCancelled else { return }
                self.applyFetchError(error)
            }
        }
    }

    /// Updates published state from successfully fetched saver profiles.
    private func applyFetchedSavers(_ saverProfiles: [PlaceSaverProfile], placeId: String) {
        let followed = saverProfiles.filter { $0.isFollowed }.map { $0.toProfileData() }
        let unfollowed = saverProfiles.filter { !$0.isFollowed }.map { $0.toProfileData() }

        let userSaved: Bool
        if let currentUserId = userSession.currentUserId {
            userSaved = saverProfiles.contains { $0.userId == currentUserId }
        } else {
            userSaved = false
        }

        followedSavers = followed
        unfollowedSavers = unfollowed
        totalSaverCount = saverProfiles.count
        totalGlobalSaveCount = saverProfiles.count
        currentUserSaved = userSaved
        reviewedSaverIds = Set(saverProfiles.filter { $0.hasReviewed == true }.map { $0.userId })
        error = nil
        isLoading = false

        let saverIds = saverProfiles.map { $0.userId }
        if !saverIds.isEmpty {
            onSaversUpdated?(placeId, saverIds)
        }
    }

    /// Updates published state when fetching savers fails.
    private func applyFetchError(_ error: Error) {
        self.error = error
        isLoading = false
        totalSaverCount = 0
        totalGlobalSaveCount = 0
        followedSavers = []
        unfollowedSavers = []
    }
    
    /// Clears all saver data and resets loading state.
    private func resetState() {
        followedSavers = []
        unfollowedSavers = []
        isLoading = false
        error = nil
        currentUserSaved = false
        totalSaverCount = 0
        totalGlobalSaveCount = 0
        reviewedSaverIds = []
    }
}

