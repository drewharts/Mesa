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
                // World Map Banner (extends to top of screen)
                WorldMapBannerView(
                    visitedCountryCodes: CountryISOMapping.isoCodesFromNames(viewModel.visitedCountries),
                    height: 230
                )

                // Profile Picture, Name, Followers
                VStack(spacing: 16) {
                    // Profile Picture (overlapping banner bottom)
                    UserProfileProfilePictureView(
                        profilePhotoURL: viewModel.user.profilePhotoURL,
                        isFollowing: viewModel.isFollowing,
                        onToggleFollow: {
                            guard let currentUserId = userSession.currentUserId else { return }
                            viewModel.toggleFollowUser(currentUserId: currentUserId) { success, newFollowingState in
                                if success {
                                    profileVM.socialViewModel.updateFollowingState(
                                        userId: viewModel.userId,
                                        isFollowing: newFollowingState
                                    )
                                }
                            }
                        },
                        totalPlacesCount: viewModel.totalPlacesCount,
                        userName: viewModel.user.firstName ?? viewModel.user.fullName
                    )
                    .offset(y: -50)
                    .padding(.bottom, -50)

                    // Name
                    Text(viewModel.user.fullName)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.black)

                    // Clickable Followers/Following counts & Social Links
                    ProfileFollowCountsView(
                        data: .external(
                            followers: viewModel.followers,
                            following: viewModel.followingCount,
                            instagramUsername: viewModel.user.instagramUsername,
                            tiktokUsername: viewModel.user.tiktokUsername
                        ),
                        onFollowersTap: { showFollowers = true },
                        onFollowingTap: { showFollowing = true }
                    )
                }
                .padding(.bottom, 16)

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
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
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
