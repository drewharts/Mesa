//
//  ProfileFollowingListView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/26/25.
//
//  Unified following list view for external profiles.
//  Uses @ObservedObject ExternalUserProfileViewModel for per-profile state.
//  Navigates to UserRow which uses ExternalUserProfileViewWrapper for nested navigation.
//

import SwiftUI

/// Displays a paginated list of users that an external user is following.
struct ProfileFollowingListView: View {
    @ObservedObject var viewModel: ExternalUserProfileViewModel
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var detailPlaceVM: DetailPlaceViewModel
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var userProfileVM: UserProfileViewModel
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var dataManager: DataManager

    var body: some View {
        VStack {
            if viewModel.externalUserFollowing.isEmpty {
                if viewModel.isExternalFollowingLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else {
                    VStack(spacing: 16) {
                        Spacer()
                        Text("Not Following Anyone Yet")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)

                        Text("When this user follows someone, they'll appear here.")
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Spacer()
                    }
                }
            } else {
                List {
                    ForEach(viewModel.externalUserFollowing) { user in
                        UserRow(user: user)
                            .onAppear {
                                // Load profile picture when row appears
                                detailPlaceVM.loadProfilePictureIfNeeded(for: user)

                                // Load more when user scrolls to the last few items
                                if let index = viewModel.externalUserFollowing.firstIndex(where: { $0.id == user.id }),
                                   index >= viewModel.externalUserFollowing.count - 3,
                                   !viewModel.isExternalFollowingLoading,
                                   viewModel.hasMoreExternalFollowing {
                                    viewModel.loadExternalFollowing(offset: viewModel.externalUserFollowing.count)
                                }
                            }
                    }

                    // Loading indicator at bottom while loading more
                    if viewModel.isExternalFollowingLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding()
                            Spacer()
                        }
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(PlainListStyle())
                .refreshable {
                    // Pull-to-refresh: reload following data
                    viewModel.loadExternalFollowing(offset: 0)
                }
            }
        }
        .navigationTitle("Following")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Only load on initial appearance if list is empty
            if viewModel.externalUserFollowing.isEmpty && !viewModel.isExternalFollowingLoading {
                viewModel.loadExternalFollowing(offset: 0)
            }
        }
    }
}
