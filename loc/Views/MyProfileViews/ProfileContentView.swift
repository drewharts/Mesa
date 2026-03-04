//
//  ProfileContentView.swift
//  loc
//
//  Created by Claude on 1/13/25.
//

import SwiftUI
import PhotosUI

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

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    // World Map Banner (extends to top of screen)
                    WorldMapBannerView(
                        visitedCountryCodes: CountryISOMapping.isoCodesFromNames(profile.visitedCountries),
                        height: 230
                    )

                    VStack(spacing: 12) {
                    // Profile Picture (overlapping banner bottom)
                    ProfilePictureView()
                        .offset(y: -50)
                        .padding(.bottom, -50)

                    // Name
                    let firstName = profile.user?.firstName ?? ""
                    let lastName = profile.user?.lastName ?? ""
                    Text("\(firstName) \(lastName)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.black)

                    // Follow Counts & Social Links
                    ProfileFollowCountsView(
                        data: .myProfile(
                            followers: socialVM.followersCount,
                            following: socialVM.followingCount,
                            isFollowersLoading: socialVM.isFollowersLoading,
                            isFollowingLoading: socialVM.isFollowingLoading,
                            instagramUsername: profile.user?.instagramUsername,
                            tiktokUsername: profile.user?.tiktokUsername
                        ),
                        onFollowersTap: {
                            navigationPath.append(ProfileView.FollowListDestination.followers)
                        },
                        onFollowingTap: {
                            navigationPath.append(ProfileView.FollowListDestination.following)
                        },
                        onAddSocialsTap: {
                            showEditProfileForSocials = true
                        }
                    )
                    .onAppear {
                        Task {
                            await profile.loadProfileCounts()
                        }
                    }

                    // Favorites/Videos (tabbed) & Lists
                    ProfileFavoritesExternalPlacesView(
                        favoritesVM: favoritesVM,
                        externalContentVM: externalContentVM,
                        reviewsVM: reviewsVM,
                        myPlacesVM: myPlacesVM
                    )
                    ProfileViewListsView(listsVM: listsVM)

                    // No Location Data Error
                    if photoImportVM.noLocationDataError {
                        VStack(spacing: 12) {
                            Text("📍 NO LOCATION DATA")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            VStack(spacing: 8) {
                                Text("None of the selected photos contain GPS coordinates")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                
                                Text("To create a review, please select photos taken with location services enabled")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.9))
                                    .multilineTextAlignment(.center)
                            }
                            
                            Button("TRY AGAIN") {
                                photoImportVM.clearSelection()
                            }
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.white)
                            .cornerRadius(8)
                        }
                        .padding(20)
                        .background(Color.red)
                        .cornerRadius(15)
                        .padding(.horizontal, 20)
                        .shadow(radius: 10)
                    }
                    
                    // Photo Processing Display
                    else if let coordinates = photoImportVM.detectedCoordinates {
                        VStack(spacing: 12) {
                            Text("📍 PHOTO COORDINATES")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            VStack(spacing: 8) {
                                Text("Latitude: \(coordinates.latitude, specifier: "%.6f")")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                
                                Text("Longitude: \(coordinates.longitude, specifier: "%.6f")")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }
                            
                            // Loading nearby places indicator
                            if photoImportVM.isLoadingNearbyPlaces {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Finding nearby places...")
                                        .font(.subheadline)
                                }
                                .foregroundColor(.white)
                            }
                            
                            // Selected place display
                            if let selectedPlace = photoImportVM.selectedPlace {
                                VStack(spacing: 4) {
                                    Text("✅ Selected Place:")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                    Text(selectedPlace.properties.name)
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                }
                            }
                            
                            Button("CLEAR ALL") {
                                photoImportVM.clearSelection()
                            }
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.white)
                            .cornerRadius(8)
                        }
                        .padding(20)
                        .background(Color.blue)
                        .cornerRadius(15)
                        .padding(.horizontal, 20)
                        .shadow(radius: 10)
                    }

                    // Account actions (logout/delete) moved to toolbar AccountMenuView
                    }
                }
                .padding(.bottom, 40)
            }
            .refreshable {
                await profile.refreshProfile()
            }
            .ignoresSafeArea(edges: .top)
        }
        .sheet(isPresented: $showEditProfileForSocials) {
            if let user = profile.user {
                EditProfileView(user: user) { updatedUser in
                    profile.user = updatedUser
                }
            }
        }
    }

}

