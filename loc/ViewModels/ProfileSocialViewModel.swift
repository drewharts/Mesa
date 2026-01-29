//
//  ProfileSocialViewModel.swift
//  loc
//
//  Created by Andrew Hartsfield II on 01/29/26.
//

import SwiftUI
import Combine

/// Manages social features for the current user's profile: followers, following, and follow/unfollow actions.
@MainActor
class ProfileSocialViewModel: ObservableObject {
    // MARK: - Published Properties

    /// List of users the current user is following
    @Published var userFollowing: [ProfileData] = []

    /// List of users following the current user
    @Published var userFollowers: [ProfileData] = []

    /// Total count of followers
    @Published var followersCount: Int = 0

    /// Total count of users being followed
    @Published var followingCount: Int = 0

    /// Loading state for followers count
    @Published var isFollowersLoading: Bool = true

    /// Loading state for following count
    @Published var isFollowingLoading: Bool = true

    /// Loading state for followers list (popup)
    @Published var isFollowersListLoading: Bool = false

    /// Loading state for following list (popup)
    @Published var isFollowingListLoading: Bool = false

    /// Whether more followers can be loaded (pagination)
    @Published var hasMoreFollowers: Bool = true

    /// Whether more following can be loaded (pagination)
    @Published var hasMoreFollowing: Bool = true

    /// Error alert state for follow actions
    @Published var showFollowError: Bool = false

    /// Error message for follow actions
    @Published var followErrorMessage: String = ""

    // MARK: - Dependencies

    private let userService: UserService
    private weak var userSession: UserSession?

    // MARK: - Initialization

    /// Initializes the social view model with required dependencies.
    init(userService: UserService, userSession: UserSession) {
        self.userService = userService
        self.userSession = userSession
    }

    // MARK: - Public Methods

    /// Toggles follow/unfollow state for a user with optimistic UI updates.
    func toggleFollowUser(userId: String, currentUserId: String?) {
        guard let currentUserId = currentUserId else { return }

        // Store original state for potential rollback
        let originalFollowingCount = followingCount
        let originalUserFollowing = userFollowing

        // Capture userService before entering closures to avoid MainActor isolation issues
        let service = userService

        if userFollowing.contains(where: { $0.id == userId }) {
            // Optimistic update: immediately change UI
            userFollowing.removeAll { $0.id == userId }
            followingCount = max(0, followingCount - 1)

            // Make the actual API call
            service.unfollowUser(followerId: currentUserId, followingId: userId) { [weak self] (success: Bool, error: Error?) in
                if !success {
                    // Revert on failure
                    DispatchQueue.main.async {
                        self?.userFollowing = originalUserFollowing
                        self?.followingCount = originalFollowingCount
                        self?.showFollowError = true
                        self?.followErrorMessage = "Failed to unfollow user. Please try again."
                    }
                }
            }
        } else {
            // Optimistic update: immediately change UI
            followingCount += 1

            // Make the actual API call
            service.followUser(followerId: currentUserId, followingId: userId) { [weak self] (success: Bool, error: Error?) in
                if success {
                    // Fetch the ProfileData for the followed user and add to userFollowing
                    service.fetchUserById(userId: userId) { (result: Result<ProfileData, Error>) in
                        if case .success(let profileData) = result {
                            DispatchQueue.main.async {
                                self?.userFollowing.append(profileData)
                            }
                        }
                    }
                } else {
                    // Revert on failure
                    DispatchQueue.main.async {
                        self?.userFollowing = originalUserFollowing
                        self?.followingCount = originalFollowingCount
                        self?.showFollowError = true
                        self?.followErrorMessage = "Failed to follow user. Please try again."
                    }
                }
            }
        }
    }

    /// Updates local following state after external follow/unfollow action.
    /// This does NOT make an API call - it only updates local state.
    func updateFollowingState(userId: String, isFollowing: Bool) {
        if isFollowing {
            // Add to following list if not already there
            if !userFollowing.contains(where: { $0.id == userId }) {
                followingCount += 1
                // Capture userService before entering closure to avoid MainActor isolation issues
                let service = userService
                // Fetch the user profile and add to following list
                service.fetchUserById(userId: userId) { [weak self] (result: Result<ProfileData, Error>) in
                    if case .success(let profileData) = result {
                        DispatchQueue.main.async {
                            self?.userFollowing.append(profileData)
                        }
                    }
                }
            }
        } else {
            // Remove from following list
            if userFollowing.contains(where: { $0.id == userId }) {
                userFollowing.removeAll { $0.id == userId }
                followingCount = max(0, followingCount - 1)
            }
        }
    }

    /// Checks if the current user is following a specific user.
    func isFollowing(userId: String) -> Bool {
        return userFollowing.contains { $0.id == userId }
    }

    /// Resets all social data (used during logout).
    func resetAllData() {
        userFollowing.removeAll()
        userFollowers.removeAll()
        followersCount = 0
        followingCount = 0
        showFollowError = false
        followErrorMessage = ""
        hasMoreFollowers = true
        hasMoreFollowing = true
        isFollowersLoading = true
        isFollowingLoading = true
        isFollowersListLoading = false
        isFollowingListLoading = false
    }
}
