//
//  CityUserProfileView.swift
//  loc
//
//  Loading wrapper that fetches a user by ID, then renders their profile
//  within the city detail sheet's NavigationStack.
//

import SwiftUI

/// Loads a user's ProfileData, then hands off to CityUserProfileContentWrapper.
struct CityUserProfileView: View {
    let userId: String
    @StateObject private var viewModel: CityUserProfileViewModel

    init(userId: String) {
        self.userId = userId
        self._viewModel = StateObject(wrappedValue: CityUserProfileViewModel(userId: userId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading profile...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.loadError {
                VStack(spacing: 16) {
                    Text("Error loading profile")
                        .font(.headline)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else if let profileData = viewModel.profileData {
                CityUserProfileContentWrapper(user: profileData)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadUser()
        }
    }
}
