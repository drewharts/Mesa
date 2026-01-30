//
//  FollowersListView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/16/24.
//

import SwiftUI
import UIKit

struct FollowersListView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var detailPlaceVM: DetailPlaceViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel

    /// Convenience accessor for social view model
    private var socialVM: ProfileSocialViewModel { profile.socialViewModel }

    var body: some View {
        VStack {
            if socialVM.userFollowers.isEmpty {
                if socialVM.isFollowersListLoading {
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

                        Text("When someone follows you, they'll appear here.")
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Spacer()
                    }
                }
            } else {
                List {
                    ForEach(socialVM.userFollowers) { user in
                        UserRow(user: user)
                            .onAppear {
                                // Load more when user scrolls to the last few items
                                if let index = socialVM.userFollowers.firstIndex(where: { $0.id == user.id }),
                                   index >= socialVM.userFollowers.count - 3,
                                   !socialVM.isFollowersListLoading,
                                   socialVM.hasMoreFollowers {
                                    Task {
                                        await dataManager.loadFollowers(userId: userSession.currentUserId ?? "", offset: socialVM.userFollowers.count)
                                    }
                                }
                            }
                    }

                    // Loading indicator at bottom while loading more
                    if socialVM.isFollowersListLoading {
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
                    // MVVM: View coordinates refresh action, ViewModel manages data
                    await dataManager.loadFollowers(userId: userSession.currentUserId ?? "", offset: 0)
                }
            }
        }
        .navigationTitle("Followers")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Only load on initial appearance if list is empty (first-time users)
            // Enterprise: Don't reload on every appearance - preserves scroll position and avoids unnecessary network calls
            if socialVM.userFollowers.isEmpty && !socialVM.isFollowersListLoading {
                await dataManager.loadFollowers(userId: userSession.currentUserId ?? "", offset: 0)
            }
        }
    }
}
