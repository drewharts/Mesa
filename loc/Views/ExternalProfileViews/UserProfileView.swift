//
//  UserProfileView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/29/25.
//
//  Refactored: Removed top-level Profile/Reviews tabs for design consistency
//  with ProfileView. Reviews now appear next to Favorites in a tab section.
//

import SwiftUI

struct UserProfileView: View {
    let userId: String
    @ObservedObject var UserProfileVM: UserProfileViewModel
    @EnvironmentObject var profileVM: ProfileViewModel
    @EnvironmentObject var userSession: UserSession // Add userSession to get current user ID
    @EnvironmentObject var detailPlaceVM: DetailPlaceViewModel
    @EnvironmentObject var serviceContainer: ServiceContainer
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
            // Show loading state if selectedUser is not yet set
            if UserProfileVM.selectedUser == nil {
                ProgressView("Loading profile...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            } else {
            // Profile Picture, Name, Followers
                VStack(spacing: 16) {
                    // Profile Picture
                    UserProfileProfilePictureView(
                        profilePhotoURL: UserProfileVM.selectedUser?.profilePhotoURL,
                        isFollowing: UserProfileVM.isFollowing,
                        onToggleFollow: {
                            // Single responsibility: Only UserProfileViewModel makes the API call
                            // Use currentUserId from userSession, not userId (which is the viewed profile)
                            guard let currentUserId = userSession.currentUserId else { return }
                            UserProfileVM.toggleFollowUser(currentUserId: currentUserId) { success, newFollowingState in
                                if success {
                                    // Update ProfileViewModel's local state WITHOUT making another API call
                                    if let userId = UserProfileVM.selectedUser?.id {
                                        profileVM.updateFollowingState(
                                            userId: userId,
                                            isFollowing: newFollowingState
                                        )
                                    }
                                }
                            }
                        },
                        totalPlacesCount: UserProfileVM.totalPlacesCount,
                        userName: UserProfileVM.selectedUser?.firstName ?? UserProfileVM.selectedUser?.fullName ?? ""
                    )

                    // Name
                    Text(UserProfileVM.selectedUser?.fullName ?? "")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.black)

                    // Clickable Followers/Following counts
                    ExternalProfileFollowCountsView()
                        .environmentObject(UserProfileVM)
                }
                .padding(.top, -8)
                .padding(.bottom, 16)

                Divider()
                    .padding(.horizontal, 20)

            // Content section
                    VStack(spacing: 20) {
            // Favorites & Reviews (with tabs like ProfileFavoritesTikToksView)
            // Note: Divider is included inside UserProfileFavoritesReviewsView
            UserProfileFavoritesReviewsView(userProfileVM: UserProfileVM)
                .padding(.top, 16)

            // Place Lists
                        UserProfileListsView(viewModel: UserProfileVM, placeLists: UserProfileVM.userLists)

                        Spacer(minLength: 50)
            }
                    }
            }
        }
        .environmentObject(UserProfileVM)
        .task {
            // Use .task instead of .onAppear to ensure it runs after selectUser sets selectedUser
            // Use currentUserId from userSession, not userId (which is the viewed profile)
            guard let currentUserId = userSession.currentUserId else { return }
            // Only check if following if selectedUser is already set (from selectUser in UserRow)
            if UserProfileVM.selectedUser != nil {
                UserProfileVM.checkIfFollowing(currentUserId: currentUserId)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if let selectedUser = UserProfileVM.selectedUser {
                    ProfileShareButton(
                        userId: selectedUser.id,
                        fullName: selectedUser.fullName,
                        profilePhotoURL: selectedUser.profilePhotoURL?.absoluteString,
                        style: .toolbar
                    )
                }
            }
        }
        .alert("Follow Error", isPresented: $UserProfileVM.showFollowError) {
            Button("OK") {
                UserProfileVM.showFollowError = false
            }
        } message: {
            Text(UserProfileVM.followErrorMessage)
        }
        .alert("Follow Error", isPresented: $profileVM.showFollowError) {
            Button("OK") {
                profileVM.showFollowError = false
            }
        } message: {
            Text(profileVM.followErrorMessage)
        }
    }
}
