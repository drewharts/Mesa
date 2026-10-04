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
    @EnvironmentObject var userProfileNavigationVM: UserProfileNavigationViewModel
    @EnvironmentObject var mapDisplayCoordinatorVM: MapDisplayCoordinatorViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.presentationMode) var presentationMode

    @State private var showFollowers = false
    @State private var showFollowing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Profile Picture (left) + name/follow counts (right), Follow button below —
                // condensed horizontal header so more content is visible without scrolling.
                VStack(spacing: 12) {
                    HStack(alignment: .top, spacing: 14) {
                        UserProfileProfilePictureView(profilePhotoURL: viewModel.user.profilePhotoURL)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 10) {
                                Text(viewModel.user.fullName)
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.black)

                                ProfileSocialLinksRow(
                                    instagramUsername: viewModel.user.instagramUsername,
                                    tiktokUsername: viewModel.user.tiktokUsername
                                )
                            }

                            // Clickable Followers/Following/Places counts
                            ProfileFollowCountsView(
                                data: .external(
                                    followers: viewModel.followers,
                                    following: viewModel.followingCount,
                                    places: viewModel.totalPlacesCount
                                ),
                                onFollowersTap: { showFollowers = true },
                                onFollowingTap: { showFollowing = true },
                                hideFollowing: viewModel.isCuratedProfile
                            )
                        }

                        Spacer(minLength: 0)
                    }

                    Button(action: {
                        guard let currentUserId = userSession.currentUserId else { return }
                        viewModel.toggleFollowUser(currentUserId: currentUserId) { success, newFollowingState in
                            if success {
                                profileVM.socialViewModel.updateFollowingState(
                                    userId: viewModel.userId,
                                    isFollowing: newFollowingState
                                )
                            }
                        }
                    }) {
                        Text(viewModel.isFollowing ? "Following" : "Follow")
                            .font(.system(size: 14, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .foregroundColor(viewModel.isFollowing ? .primary : .white)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(viewModel.isFollowing ? Color(.systemGray5) : Color.blue)
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 16)

                Divider()
                    .padding(.horizontal, 20)

                // Content section
                VStack(spacing: 20) {
                    // Favorites & Reviews (hidden for curated/brand profiles)
                    if !viewModel.isCuratedProfile {
                        ExternalUserProfileFavoritesReviewsView(viewModel: viewModel)
                            .padding(.top, 16)
                    }

                    // Place Lists
                    ExternalUserProfileListsView(viewModel: viewModel, placeLists: viewModel.userLists)
                        .padding(.top, viewModel.isCuratedProfile ? 16 : 0)

                    Spacer(minLength: 50)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .background(
            Group {
                NavigationLink(
                    destination: ProfileFollowersListView(viewModel: viewModel)
                        .environmentObject(profileVM)
                        .environmentObject(detailPlaceVM)
                        .environmentObject(userSession)
                        .environmentObject(selectedPlaceVM)
                        .environmentObject(userProfileNavigationVM)
                        .environmentObject(mapDisplayCoordinatorVM)
                        .environmentObject(locationManager)
                        .environmentObject(dataManager),
                    isActive: $showFollowers
                ) {
                    EmptyView()
                }

                if !viewModel.isCuratedProfile {
                    NavigationLink(
                        destination: ProfileFollowingListView(viewModel: viewModel)
                            .environmentObject(profileVM)
                            .environmentObject(detailPlaceVM)
                            .environmentObject(userSession)
                            .environmentObject(selectedPlaceVM)
                            .environmentObject(userProfileNavigationVM)
                            .environmentObject(mapDisplayCoordinatorVM)
                            .environmentObject(locationManager)
                            .environmentObject(dataManager),
                        isActive: $showFollowing
                    ) {
                        EmptyView()
                    }
                }
            }
        )
        .alert("Follow Error", isPresented: $viewModel.showFollowError) {
            Button("OK") {
                viewModel.showFollowError = false
            }
        } message: {
            Text(viewModel.followErrorMessage)
        }
        .alert("Follow Error", isPresented: Binding(
            get: { profileVM.socialViewModel.showFollowError },
            set: { profileVM.socialViewModel.showFollowError = $0 }
        )) {
            Button("OK") {
                profileVM.socialViewModel.showFollowError = false
            }
        } message: {
            Text(profileVM.socialViewModel.followErrorMessage)
        }
    }
}
