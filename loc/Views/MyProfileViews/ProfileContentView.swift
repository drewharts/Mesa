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
    @EnvironmentObject var dataManager: DataManager
    @ObservedObject var photoImportVM: PhotoImportViewModel
    @Binding var navigationPath: NavigationPath
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Profile Picture
                    ProfilePictureView()

                    // Name
                    let firstName = profile.user?.firstName ?? ""
                    let lastName = profile.user?.lastName ?? ""
                    Text("\(firstName) \(lastName)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.black)

                    // Follow Counts
                    ProfileFollowCountsView(
                        data: .myProfile(
                            followers: profile.socialViewModel.followersCount,
                            following: profile.socialViewModel.followingCount,
                            myPlaces: profile.myPlacesViewModel.myPlaces.count,
                            isFollowersLoading: profile.socialViewModel.isFollowersLoading,
                            isFollowingLoading: profile.socialViewModel.isFollowingLoading,
                            isMyPlacesLoading: profile.myPlacesViewModel.isMyPlacesLoading
                        ),
                        onFollowersTap: {
                            navigationPath.append(ProfileView.FollowListDestination.followers)
                        },
                        onFollowingTap: {
                            navigationPath.append(ProfileView.FollowListDestination.following)
                        },
                        onMyPlacesTap: {
                            profile.showMyPlacesOnMap = true
                            presentationMode.wrappedValue.dismiss()
                        }
                    )
                    .onAppear {
                        let userId = userSession.currentUserId ?? ""
                        Task.detached(priority: .userInitiated) { [dataManager] in
                            await dataManager.loadProfileCounts(userId: userId)
                        }
                    }

                    Divider()
                        .padding(.top, 15)
                        .padding(.horizontal, 20)
                    
                    // Favorites/TikToks (tabbed) & Lists
                    ProfileFavoritesTikToksView()
                    ProfileViewListsView()

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
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
    }
}

