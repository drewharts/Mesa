//
//  ExternalFollowersListView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/26/25.
//
//  For the DEEP LINK path: Uses @EnvironmentObject UserProfileViewModel.
//  Navigates to UserRow which uses UserProfileView for continued deep link navigation.
//

import SwiftUI

struct ExternalFollowersListView: View {
    @EnvironmentObject var userProfileVM: UserProfileViewModel
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var detailPlaceVM: DetailPlaceViewModel
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel

    var body: some View {
        VStack {
            if userProfileVM.externalUserFollowers.isEmpty {
                if userProfileVM.isExternalFollowersLoading {
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
                    ForEach(userProfileVM.externalUserFollowers) { user in
                        UserRow(user: user)
                            .onAppear {
                                // Load more when user scrolls to the last few items
                                if let index = userProfileVM.externalUserFollowers.firstIndex(where: { $0.id == user.id }),
                                   index >= userProfileVM.externalUserFollowers.count - 3,
                                   !userProfileVM.isExternalFollowersLoading,
                                   userProfileVM.hasMoreExternalFollowers {
                                    userProfileVM.loadExternalFollowers(offset: userProfileVM.externalUserFollowers.count)
                                }
                            }
                    }

                    // Loading indicator at bottom while loading more
                    if userProfileVM.isExternalFollowersLoading {
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
                    userProfileVM.loadExternalFollowers(offset: 0)
                }
            }
        }
        .navigationTitle("Followers")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Only load on initial appearance if list is empty
            if userProfileVM.externalUserFollowers.isEmpty && !userProfileVM.isExternalFollowersLoading {
                userProfileVM.loadExternalFollowers(offset: 0)
            }
        }
    }
}
