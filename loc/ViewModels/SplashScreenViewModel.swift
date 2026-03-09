//
//  SplashScreenViewModel.swift
//  loc
//
//  Created by Claude on 3/9/26.
//

import SwiftUI

@MainActor
class SplashScreenViewModel: ObservableObject {
    @Published var isActive = false

    private let userSession: UserSession
    private let dataManager: DataManager

    init(userSession: UserSession, dataManager: DataManager) {
        self.userSession = userSession
        self.dataManager = dataManager
    }

    /// Checks for an existing session and transitions to the main app.
    func checkSessionAndTransition() async {
        do {
            let profileId = try await resolveProfileId()

            userSession.setUserLoggedIn(uid: profileId)
            userSession.needsPhoneOnboarding = !UserSession.hasCompletedPhoneOnboarding
            userSession.needsProfilePhoto = !UserSession.hasCompletedPhotoOnboarding
            userSession.needsListOnboarding = !UserSession.hasCompletedListOnboarding

            Task.detached(priority: .userInitiated) {
                await self.dataManager.initializeProfileData(userId: profileId)
            }

            try? await Task.sleep(nanoseconds: 300_000_000)
        } catch {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }

        withAnimation { isActive = true }
    }

    /// Resolves the user's profile ID, using a local cache when available.
    private func resolveProfileId() async throws -> String {
        let session = try await SupabaseAuthService.shared.getSession()

        if let cached = UserSession.cachedProfileId {
            Task.detached(priority: .utility) {
                if let profile = try? await UserService.shared.fetchUserById(userId: session.user.id.uuidString) {
                    await MainActor.run { self.userSession.cacheProfileId(profile.id) }
                }
            }
            return cached
        }

        let profile = try await UserService.shared.fetchUserById(userId: session.user.id.uuidString)
        userSession.cacheProfileId(profile.id)
        return profile.id
    }
}
