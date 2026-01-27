//
//  ExternalUserProfileContentView.swift
//  loc
//
//  Content view for external user profiles using ExternalUserProfileViewModel.
//  This view is presented inside ExternalUserProfileViewWrapper which owns the @StateObject.
//

import SwiftUI

struct ExternalUserProfileContentView: View {
    @ObservedObject var viewModel: ExternalUserProfileViewModel
    @EnvironmentObject var profileVM: ProfileViewModel
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var detailPlaceVM: DetailPlaceViewModel
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Profile Picture, Name, Followers
                VStack(spacing: 16) {
                    // Profile Picture
                    UserProfileProfilePictureView(
                        profilePhotoURL: viewModel.user.profilePhotoURL,
                        isFollowing: viewModel.isFollowing,
                        onToggleFollow: {
                            guard let currentUserId = userSession.currentUserId else { return }
                            viewModel.toggleFollowUser(currentUserId: currentUserId) { success, newFollowingState in
                                if success {
                                    profileVM.updateFollowingState(
                                        userId: viewModel.userId,
                                        isFollowing: newFollowingState
                                    )
                                }
                            }
                        },
                        totalPlacesCount: viewModel.totalPlacesCount,
                        userName: viewModel.user.firstName ?? viewModel.user.fullName
                    )

                    // Name
                    Text(viewModel.user.fullName)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.black)

                    // Clickable Followers/Following counts (uses Nested* views for nested navigation)
                    NestedProfileFollowCountsView(viewModel: viewModel)
                }
                .padding(.top, -8)
                .padding(.bottom, 16)

                Divider()
                    .padding(.horizontal, 20)

                // Content section
                VStack(spacing: 20) {
                    // Favorites & Reviews
                    ExternalUserProfileFavoritesReviewsView(viewModel: viewModel)
                        .padding(.top, 16)

                    // Place Lists
                    ExternalUserProfileListsView(viewModel: viewModel, placeLists: viewModel.userLists)

                    Spacer(minLength: 50)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert("Follow Error", isPresented: $viewModel.showFollowError) {
            Button("OK") {
                viewModel.showFollowError = false
            }
        } message: {
            Text(viewModel.followErrorMessage)
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
