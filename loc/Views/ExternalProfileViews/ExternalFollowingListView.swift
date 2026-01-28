//
//  ExternalFollowingListView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/26/25.
//
//  For the DEEP LINK path: Uses @EnvironmentObject UserProfileViewModel.
//  Navigates to UserRow which uses UserProfileView for continued deep link navigation.
//

import SwiftUI

struct ExternalFollowingListView: View {
    @EnvironmentObject var userProfileVM: UserProfileViewModel
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var detailPlaceVM: DetailPlaceViewModel
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel

    var body: some View {
        VStack {
            if userProfileVM.externalUserFollowing.isEmpty {
                if userProfileVM.isExternalFollowingLoading {
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
                    ForEach(userProfileVM.externalUserFollowing) { user in
                        UserRow(user: user)
                            .onAppear {
                                // Load profile picture when row appears
                                detailPlaceVM.loadProfilePictureIfNeeded(for: user)

                                // Load more when user scrolls to the last few items
                                if let index = userProfileVM.externalUserFollowing.firstIndex(where: { $0.id == user.id }),
                                   index >= userProfileVM.externalUserFollowing.count - 3,
                                   !userProfileVM.isExternalFollowingLoading,
                                   userProfileVM.hasMoreExternalFollowing {
                                    userProfileVM.loadExternalFollowing(offset: userProfileVM.externalUserFollowing.count)
                                }
                            }
                    }

                    // Loading indicator at bottom while loading more
                    if userProfileVM.isExternalFollowingLoading {
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
                    userProfileVM.loadExternalFollowing(offset: 0)
                }
            }
        }
        .navigationTitle("Following")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Only load on initial appearance if list is empty
            if userProfileVM.externalUserFollowing.isEmpty && !userProfileVM.isExternalFollowingLoading {
                userProfileVM.loadExternalFollowing(offset: 0)
            }
        }
    }
}
