//
//  ListOnboardingViewModel.swift
//  loc
//
//  ViewModel: Fetches existing lists for the onboarding import flow.
//  Single Responsibility: Provide the user's existing lists to GoogleMapsImportView during onboarding.
//

import Foundation

@MainActor
class ListOnboardingViewModel: ObservableObject {

    // MARK: - Published State

    @Published var existingLists: [LightweightPlaceList] = []

    // MARK: - Dependencies

    private let userService = ServiceContainer.shared.userService

    // MARK: - Data Loading

    /// Fetches the user's existing lists so they can add imported places to one.
    func fetchExistingLists(userId: String) async {
        guard !userId.isEmpty else { return }
        do {
            existingLists = try await userService.fetchPlaceListsWithoutLocation(userId: userId)
        } catch {
            print("ListOnboardingViewModel: Failed to fetch existing lists: \(error)")
        }
    }
}
