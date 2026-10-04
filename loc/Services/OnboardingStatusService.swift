//
//  OnboardingStatusService.swift
//  loc
//
//  Single Responsibility: Decides which onboarding steps a signed-in user still needs.
//
//  Completion flags live in device-local UserDefaults, so on a fresh install or a new
//  device they are all false even for users who finished onboarding long ago. This
//  service reconciles those flags with the user's server-side data so a step the
//  account already satisfies (phone saved, photo uploaded, lists created) is skipped.
//

import Foundation
import Supabase

@MainActor
final class OnboardingStatusService {

    static let shared = OnboardingStatusService()

    private let userService = UserService.shared

    private init() {}

    /// Resolves remaining onboarding steps, treating a step as done if it was completed on this device or the account's server data already satisfies it.
    func resolveStatus(userId: String) async -> OnboardingStatus {
        let local = localStatus()
        guard !local.isComplete else { return local }

        guard let profile = try? await userService.fetchUserById(userId: userId) else {
            return local
        }

        let hasPhone = !(profile.phoneNumber ?? "").isEmpty
        let hasPhoto = profile.profilePhotoURL != nil
        let hasLists = local.needsList ? await userHasLists(userId: profile.id) : true

        return OnboardingStatus(
            needsPhone: local.needsPhone && !hasPhone,
            needsProfilePhoto: local.needsProfilePhoto && !hasPhoto,
            needsList: local.needsList && !hasLists
        )
    }

    /// Returns the onboarding status recorded on this device.
    private func localStatus() -> OnboardingStatus {
        OnboardingStatus(
            needsPhone: !UserSession.hasCompletedPhoneOnboarding,
            needsProfilePhoto: !UserSession.hasCompletedPhotoOnboarding,
            needsList: !UserSession.hasCompletedListOnboarding
        )
    }

    /// Returns whether the user owns at least one list, defaulting to false if the check fails.
    private func userHasLists(userId: String) async -> Bool {
        do {
            let response = try await SupabaseManager.shared.client
                .from("place_lists")
                .select("id", head: true, count: .exact)
                .eq("user_id", value: userId)
                .execute()
            return (response.count ?? 0) > 0
        } catch {
            print("❌ [OnboardingStatusService] Failed to count lists: \(error.localizedDescription)")
            return false
        }
    }
}
