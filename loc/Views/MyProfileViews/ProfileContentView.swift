//
//  ProfileContentView.swift
//  loc
//
//  Created by Claude on 1/13/25.
//

import SwiftUI

struct ProfileContentView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var userSession: UserSession
    @ObservedObject var socialVM: ProfileSocialViewModel
    @ObservedObject var myPlacesVM: ProfileMyPlacesViewModel
    @ObservedObject var favoritesVM: ProfileFavoritesViewModel
    @ObservedObject var externalContentVM: ProfileExternalContentViewModel
    @ObservedObject var reviewsVM: ProfileReviewsViewModel
    @ObservedObject var listsVM: ProfileListsViewModel
    @ObservedObject var photoImportVM: PhotoImportViewModel
    @Binding var navigationPath: NavigationPath
    @Environment(\.presentationMode) var presentationMode
    @State private var showEditProfileForSocials = false
    @State private var showImportTooltip = !UserDefaults.standard.bool(forKey: "hasSeenPhotoImportTooltip")
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Profile Picture + socials (left column) with name/follow counts top-aligned
                    // to the right — condensed horizontal header so more content is visible
                    // below without scrolling.
                    HStack(alignment: .top, spacing: 14) {
                        ProfilePictureView()

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 10) {
                                let firstName = profile.user?.firstName ?? ""
                                let lastName = profile.user?.lastName ?? ""
                                Text("\(firstName) \(lastName)")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.black)

                                ProfileSocialLinksRow(
                                    instagramUsername: profile.user?.instagramUsername,
                                    tiktokUsername: profile.user?.tiktokUsername,
                                    onAddSocialsTap: { showEditProfileForSocials = true }
                                )
                            }

                            ProfileFollowCountsView(
                                data: .myProfile(
                                    followers: socialVM.followersCount,
                                    following: socialVM.followingCount,
                                    places: profile.totalUniquePlacesCount,
                                    isFollowersLoading: socialVM.isFollowersLoading,
                                    isFollowingLoading: socialVM.isFollowingLoading
                                ),
                                onFollowersTap: {
                                    navigationPath.append(ProfileView.FollowListDestination.followers)
                                },
                                onFollowingTap: {
                                    navigationPath.append(ProfileView.FollowListDestination.following)
                                },
                                hideFollowing: profile.isCuratedProfile
                            )
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 20)
                    .onAppear {
                        Task {
                            await profile.loadProfileCounts()
                        }
                    }

                    Divider()
                        .padding(.top, 15)
                        .padding(.horizontal, 20)

                    // Quick actions row — visible for all profiles
                    ProfileQuickActionsRow(onImportTap: { photoImportVM.handleImportButtonTap() })
                        .overlay(alignment: .top) {
                            if showImportTooltip {
                                PhotoImportTooltip(onDismiss: {
                                    withAnimation { showImportTooltip = false }
                                    UserDefaults.standard.set(true, forKey: "hasSeenPhotoImportTooltip")
                                })
                                .offset(y: -52)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                        }

                    // Favorites/Videos (tabbed) & Lists — hidden for curated profiles
                    if !profile.isCuratedProfile {
                        ProfileFavoritesExternalPlacesView(
                            favoritesVM: favoritesVM,
                            externalContentVM: externalContentVM,
                            reviewsVM: reviewsVM,
                            myPlacesVM: myPlacesVM
                        )
                    }
                    ProfileViewListsView(listsVM: listsVM)

                    // Account actions (logout/delete) moved to toolbar AccountMenuView
                }
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .refreshable {
                await profile.refreshProfile()
            }
        }
        .sheet(isPresented: $showEditProfileForSocials) {
            if let user = profile.user {
                EditProfileView(user: user) { updatedUser in
                    profile.user = updatedUser
                }
            }
        }
        .alert("No Location Data", isPresented: $photoImportVM.noLocationDataError) {
            Button("OK") { photoImportVM.clearSelection() }
        } message: {
            Text("The selected photos don't contain location data. Please select photos taken with location services enabled.")
        }
    }

}

