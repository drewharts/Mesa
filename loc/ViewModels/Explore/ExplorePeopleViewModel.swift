//
//  ExplorePeopleViewModel.swift
//  loc
//
//  Child ViewModel for the Explore tab's "People to follow" section.
//  Single Responsibility: load suggested users (never already-followed) and manage follow toggles.
//

import Foundation

@MainActor
final class ExplorePeopleViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var people: [ProfileData] = []
    @Published private(set) var followStates: [String: Bool] = [:]
    @Published private(set) var isLoading = false

    // MARK: - Dependencies

    private let userService = SupabaseUserService.shared
    private var userId: String?
    private var hasLoaded = false

    // MARK: - Loading

    /// Loads suggested users, excluding the current user and everyone they already follow.
    func load(userId: String, force: Bool = false) async {
        guard !isLoading, force || !hasLoaded else { return }
        self.userId = userId
        isLoading = true
        async let suggested = fetchSuggested(userId: userId)
        async let followed = fetchFollowedIds(userId: userId)
        let followedIds = await followed
        people = await suggested.filter { $0.id != userId && !followedIds.contains($0.id) }
        followStates = [:]
        hasLoaded = true
        isLoading = false
    }

    /// Fetches suggested users from the recommendation RPC; failures yield an empty list.
    private func fetchSuggested(userId: String) async -> [ProfileData] {
        do {
            return try await userService.fetchRecommendedUsers(userId: userId, limit: 20)
        } catch {
            print("⚠️ [ExplorePeopleVM] Failed to load suggested users: \(error)")
            return []
        }
    }

    /// Fetches the ids the user already follows; failures yield an empty set.
    private func fetchFollowedIds(userId: String) async -> Set<String> {
        do {
            return Set(try await userService.fetchFollowingUserIds(userId: userId))
        } catch {
            print("⚠️ [ExplorePeopleVM] Failed to load following ids: \(error)")
            return []
        }
    }

    // MARK: - Dismissing

    /// Removes a suggested user from the row for this session.
    func dismiss(profileId: String) {
        people.removeAll { $0.id == profileId }
    }

    // MARK: - Following

    /// Toggles follow state for a user with an optimistic update and rollback on failure.
    func toggleFollow(profileId: String) async {
        guard let userId else { return }
        let wasFollowing = followStates[profileId] ?? false
        followStates[profileId] = !wasFollowing
        do {
            if wasFollowing {
                try await userService.unfollowUser(followerId: userId, followingId: profileId)
            } else {
                try await userService.followUser(followerId: userId, followingId: profileId)
            }
        } catch {
            followStates[profileId] = wasFollowing
            print("⚠️ [ExplorePeopleVM] Failed to toggle follow for \(profileId): \(error)")
        }
    }
}
