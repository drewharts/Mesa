//
//  SuggestedProfilesViewModel.swift
//  loc
//
//  Single Responsibility: Manages state and data for the suggested profiles popup.
//  Handles profile fetching, loading states, and persistence of "popup seen" status.
//

import Foundation

@MainActor
class SuggestedProfilesViewModel: ObservableObject {

    // MARK: - Hardcoded Suggested Profile IDs

    static let suggestedProfileIds = [
        "36997cbb-bd25-4275-849d-8e9ea06fca94",  // Michelin Guide (curated)
        "658abee3-ae63-4e57-8085-65a7faed9988",  // Design Hotels (curated)
        "eb3a2527-24ab-4a0d-8327-c4938bf05adc",  // Ernest Hemingway (curated)
        "C9DFA19E-B1B0-4EF1-8697-E448BC606CC7",  // Drew Hartsfield
        "60dccc59-1c4d-4454-99f8-2a73f420a13b",  // Anthony Bourdain
        "12e271fc-6fb3-48e8-adff-dfd162523008"   // Action Bronson
    ]

    // MARK: - UserDefaults Key

    private static let hasSeenPopupKey = "hasSeenSuggestedProfilesPopup"

    // MARK: - Published State

    @Published var suggestedProfiles: [ProfileData] = []
    @Published var contactMatches: [ProfileData] = []
    @Published var isLoading = true
    @Published var isLoadingContacts = false
    @Published var contactsAccessDenied = false
    @Published var loadError: Error?
    @Published var followStates: [String: Bool] = [:]

    // MARK: - Dependencies

    private let userService: UserService
    private let supabaseUserService: SupabaseUserService
    private let contactsService: ContactsService

    /// The signed-in user, excluded from suggestions and used for follow lookups.
    private var currentUserId: String?

    // MARK: - Initialization

    init(
        userService: UserService? = nil,
        supabaseUserService: SupabaseUserService? = nil,
        contactsService: ContactsService? = nil
    ) {
        self.userService = userService ?? ServiceContainer.shared.userService
        self.supabaseUserService = supabaseUserService ?? ServiceContainer.shared.supabaseUserService
        self.contactsService = contactsService ?? ServiceContainer.shared.contactsService
    }

    // MARK: - Static Methods

    /// Returns whether the popup should be shown (first login only).
    static var shouldShowPopup: Bool {
        !UserDefaults.standard.bool(forKey: hasSeenPopupKey)
    }

    // MARK: - Public Methods

    /// Loads suggested profiles, then contact matches and the user's follow state for every displayed profile in parallel.
    func load(currentUserId: String?) async {
        self.currentUserId = currentUserId
        await loadSuggestedProfiles()
        guard let currentUserId else { return }
        async let contacts: Void = loadContactMatches(currentUserId: currentUserId)
        async let follows: Void = loadFollowStates(currentUserId: currentUserId)
        _ = await (contacts, follows)
    }

    /// Marks the popup as seen so it won't show again on future logins.
    func markPopupAsSeen() {
        UserDefaults.standard.set(true, forKey: Self.hasSeenPopupKey)
    }

    /// Loads suggested profile data from the database for display, excluding the current user.
    private func loadSuggestedProfiles() async {
        isLoading = true
        loadError = nil

        var loadedProfiles: [ProfileData] = []

        for userId in Self.suggestedProfileIds where !isCurrentUser(userId) {
            do {
                let profile = try await userService.fetchUserById(userId: userId)
                loadedProfiles.append(profile)
            } catch {
                print("⚠️ [SuggestedProfilesVM] Failed to fetch profile \(userId): \(error.localizedDescription)")
            }
        }

        suggestedProfiles = loadedProfiles
        isLoading = false

        if loadedProfiles.isEmpty {
            loadError = NSError(
                domain: "SuggestedProfilesViewModel",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Could not load suggested profiles"]
            )
        }
    }

    /// Retries loading profiles after an error occurred.
    func retry() async {
        await load(currentUserId: currentUserId)
    }

    /// Returns whether the given profile ID belongs to the signed-in user.
    private func isCurrentUser(_ profileId: String) -> Bool {
        guard let currentUserId else { return false }
        return profileId.caseInsensitiveCompare(currentUserId) == .orderedSame
    }

    // MARK: - Contact Matching

    /// Requests contacts access, fetches phone numbers, and matches them against Supabase users.
    private func loadContactMatches(currentUserId: String) async {
        isLoadingContacts = true

        let granted = await contactsService.requestAccess()
        guard granted else {
            contactsAccessDenied = true
            isLoadingContacts = false
            return
        }

        let phoneNumbers = await contactsService.fetchNormalizedPhoneNumbers()
        guard !phoneNumbers.isEmpty else {
            isLoadingContacts = false
            return
        }

        do {
            let matches = try await contactsService.matchContacts(
                phoneNumbers: phoneNumbers,
                requestingUserId: currentUserId
            )
            contactMatches = matches

            // Remove contact matches from suggested profiles to avoid duplicates
            let matchIds = Set(matches.map(\.id))
            suggestedProfiles = suggestedProfiles.filter { !matchIds.contains($0.id) }
        } catch {
            print("⚠️ [SuggestedProfilesVM] Contact matching failed: \(error.localizedDescription)")
        }

        isLoadingContacts = false
    }

    // MARK: - Follow Logic

    /// Fetches everyone the user follows in one query and marks matching profiles as followed.
    private func loadFollowStates(currentUserId: String) async {
        do {
            let followingIds = try await supabaseUserService.fetchFollowingUserIds(userId: currentUserId)
            for id in followingIds where followStates[id] == nil {
                followStates[id] = true
            }
        } catch {
            print("⚠️ [SuggestedProfilesVM] Failed to load follow states: \(error.localizedDescription)")
        }
    }

    /// Toggles follow state for a profile with optimistic update and rollback on failure.
    func toggleFollow(profileId: String, currentUserId: String) async {
        let wasFollowing = followStates[profileId] ?? false
        followStates[profileId] = !wasFollowing

        do {
            if wasFollowing {
                try await supabaseUserService.unfollowUser(
                    followerId: currentUserId,
                    followingId: profileId
                )
            } else {
                try await supabaseUserService.followUser(
                    followerId: currentUserId,
                    followingId: profileId
                )
            }
        } catch {
            followStates[profileId] = wasFollowing
            print("⚠️ [SuggestedProfilesVM] Failed to toggle follow for \(profileId): \(error.localizedDescription)")
        }
    }
}
