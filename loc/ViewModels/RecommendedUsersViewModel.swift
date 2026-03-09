//
//  RecommendedUsersViewModel.swift
//  loc
//
//  Child ViewModel for the recommended users section in the photo feed.
//  Single Responsibility: Load, merge, and manage follow state for recommended users.
//

import Foundation

@MainActor
class RecommendedUsersViewModel: ObservableObject {

    // MARK: - UserDefaults Key

    private static let dismissedKey = "recommendedUsersSectionDismissed"

    // MARK: - Published State

    @Published var recommendedUsers: [ProfileData] = []
    @Published var isLoading = false
    @Published var followStates: [String: Bool] = [:]
    @Published var isDismissed: Bool

    // MARK: - Dependencies

    private let contactsService: ContactsService
    private let supabaseUserService: SupabaseUserService
    private let userId: String

    // MARK: - Initialization

    /// Initializes the recommended users view model for a specific user.
    init(userId: String) {
        self.userId = userId
        self.contactsService = ServiceContainer.shared.contactsService
        self.supabaseUserService = ServiceContainer.shared.supabaseUserService
        self.isDismissed = UserDefaults.standard.bool(forKey: Self.dismissedKey)
    }

    // MARK: - Static

    /// Returns whether the section should be shown (not dismissed by user).
    static var shouldShow: Bool {
        !UserDefaults.standard.bool(forKey: dismissedKey)
    }

    // MARK: - Public Methods

    /// Loads contact matches and popular users, merges with contacts first, caps at 15.
    func loadRecommendedUsers() async {
        guard !isDismissed else { return }
        isLoading = true

        async let contactUsers = loadContactMatches()
        async let popularUsers = loadPopularUsers()

        let contacts = await contactUsers
        let popular = await popularUsers

        let contactIds = Set(contacts.map(\.id))
        let dedupedPopular = popular.filter { !contactIds.contains($0.id) }
        let merged = Array((contacts + dedupedPopular).prefix(15))

        recommendedUsers = merged
        isLoading = false
    }

    /// Toggles follow state for a profile with optimistic update and rollback on failure.
    func toggleFollow(profileId: String) async {
        let wasFollowing = followStates[profileId] ?? false
        followStates[profileId] = !wasFollowing

        do {
            if wasFollowing {
                try await supabaseUserService.unfollowUser(
                    followerId: userId,
                    followingId: profileId
                )
            } else {
                try await supabaseUserService.followUser(
                    followerId: userId,
                    followingId: profileId
                )
            }
        } catch {
            followStates[profileId] = wasFollowing
            print("[RecommendedUsersVM] Failed to toggle follow for \(profileId): \(error.localizedDescription)")
        }
    }

    /// Dismisses the section and persists the choice to UserDefaults.
    func dismiss() {
        isDismissed = true
        UserDefaults.standard.set(true, forKey: Self.dismissedKey)
    }

    // MARK: - Private Methods

    /// Loads contact-matched users from the device contacts. Returns empty on failure or denied permission.
    private func loadContactMatches() async -> [ProfileData] {
        let granted = await contactsService.requestAccess()
        guard granted else { return [] }

        let phoneNumbers = await contactsService.fetchNormalizedPhoneNumbers()
        guard !phoneNumbers.isEmpty else { return [] }

        do {
            return try await contactsService.matchContacts(
                phoneNumbers: phoneNumbers,
                requestingUserId: userId
            )
        } catch {
            print("[RecommendedUsersVM] Contact matching failed: \(error.localizedDescription)")
            return []
        }
    }

    /// Loads popular users ranked by total places count via RPC.
    private func loadPopularUsers() async -> [ProfileData] {
        do {
            return try await supabaseUserService.fetchRecommendedUsers(userId: userId)
        } catch {
            print("[RecommendedUsersVM] Failed to load recommended users: \(error.localizedDescription)")
            return []
        }
    }
}
