//
//  ProfileFollowersListView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/26/25.
//
//  Unified followers list view for external profiles.
//  Uses @ObservedObject ExternalUserProfileViewModel for per-profile state.
//  Navigates to UserRow which uses ExternalUserProfileViewWrapper for nested navigation.
//

import SwiftUI

/// Displays a paginated list of followers for an external user profile.
struct ProfileFollowersListView: View {
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
            if viewModel.externalUserFollowers.isEmpty {
                if viewModel.isExternalFollowersLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else {
                    VStack(spacing: 16) {
                        Spacer()
                        Text("No Followers Yet")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)

                        Text("When someone follows this user, they'll appear here.")
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Spacer()
                    }
                }
            } else {
                List {
                    ForEach(viewModel.externalUserFollowers) { user in
                        UserRow(user: user)
                            .onAppear {
                                // Load profile picture when row appears
                                detailPlaceVM.loadProfilePictureIfNeeded(for: user)

                                // Load more when user scrolls to the last few items
                                if let index = viewModel.externalUserFollowers.firstIndex(where: { $0.id == user.id }),
                                   index >= viewModel.externalUserFollowers.count - 3,
                                   !viewModel.isExternalFollowersLoading,
                                   viewModel.hasMoreExternalFollowers {
                                    viewModel.loadExternalFollowers(offset: viewModel.externalUserFollowers.count)
                                }
                            }
                    }

                    // Loading indicator at bottom while loading more
                    if viewModel.isExternalFollowersLoading {
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
                    // Pull-to-refresh: reload followers data
                    viewModel.loadExternalFollowers(offset: 0)
                }
            }
        }
        .navigationTitle("Followers")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Only load on initial appearance if list is empty
            if viewModel.externalUserFollowers.isEmpty && !viewModel.isExternalFollowersLoading {
                viewModel.loadExternalFollowers(offset: 0)
            }
        }
    }
}
