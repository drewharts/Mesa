//
//  CityUserProfileViewModel.swift
//  loc
//
//  ViewModel that fetches ProfileData by userId for use within the city detail sheet.
//

import Foundation

/// Fetches a user's ProfileData by ID so the city sheet can display their profile.
@MainActor
class CityUserProfileViewModel: ObservableObject {
    @Published var isLoading = true
    @Published var loadError: Error?
    @Published var profileData: ProfileData?

    private let userId: String
    private let userService = ServiceContainer.shared.userService

    init(userId: String) {
        self.userId = userId
    }

    /// Fetches the user profile from the backend.
    func loadUser() async {
        isLoading = true
        do {
            let profile = try await userService.fetchUserById(userId: userId)
            self.profileData = profile
        } catch {
            self.loadError = error
        }
        isLoading = false
    }
}
