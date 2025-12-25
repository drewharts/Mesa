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
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Profile Picture, Name, Followers
                VStack(spacing: 20) {
                    // Profile Picture
                    UserProfileProfilePictureView(
                        profilePhotoURL: UserProfileVM.selectedUser?.profilePhotoURL,
                        isFollowing: UserProfileVM.isFollowing,
                        onToggleFollow: {
                            // Single responsibility: Only UserProfileViewModel makes the API call
                            UserProfileVM.toggleFollowUser(currentUserId: userId) { success, newFollowingState in
                                if success {
                                    // Update ProfileViewModel's local state WITHOUT making another API call
                                    profileVM.updateFollowingState(
                                        userId: UserProfileVM.selectedUser!.id, 
                                        isFollowing: newFollowingState
                                    )
                                }
                            }
                        },
                        totalPlacesCount: UserProfileVM.totalPlacesCount,
                        userName: UserProfileVM.selectedUser?.firstName ?? UserProfileVM.selectedUser?.fullName ?? ""
                    )

                    // Name
                    Text(UserProfileVM.selectedUser!.fullName)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                    
                    VStack {
                        Text("\(UserProfileVM.followers)")
                            .foregroundStyle(.black)
                        Text("Followers")
                            .foregroundStyle(.black)
                            .font(.footnote)
                            .fontWeight(.light)
                    }
                }
                .padding(.top, 8)
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
        .environmentObject(UserProfileVM)
        .onAppear {
            UserProfileVM.checkIfFollowing(currentUserId: userId)
        }
        .navigationBarTitleDisplayMode(.inline)
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
