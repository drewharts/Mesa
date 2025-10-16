//
//  ProfileFollowCountsView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/16/24.
//

import SwiftUI

struct ProfileFollowCountsView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @State private var showingFollowers = false
    @State private var showingFollowing = false
    @State private var showingMyPlaces = false
    @State private var refreshToggle = false
    
    // Calculate total My Places count (created + reviewed + TikTok)
    var totalMyPlacesCount: Int {
        let createdCount = profile.myPlaces.count
        
        // Get reviewed places count (excluding created places)
        let reviewedPlaceIds = profile.detailPlaceViewModel.placeSavers.compactMap { (placeId, userIds) -> String? in
            guard let currentUserId = profile.user?.id else { return nil }
            return userIds.contains(currentUserId) && !profile.myPlaces.contains(placeId) ? placeId : nil
        }
        let reviewedCount = reviewedPlaceIds.count
        
        // Get TikTok places count
        let tikTokCount = profile.getTikTokPlaces().count
        
        return createdCount + reviewedCount + tikTokCount
    }
    
    var body: some View {
        HStack(spacing: 24) {
            // Followers count
            Button(action: {
                showingFollowers = true
            }) {
                VStack {
                    if profile.isFollowersLoading {
                        ProgressView()
                            .frame(width: 20, height: 20)
                    } else {
                        Text("\(profile.followersCount)")
                            .font(.headline)
                            .foregroundColor(.black)
                            .fontWeight(.regular)
                            .id("followers_\(refreshToggle)")
                            .onAppear {
                                print("🔍 [ProfileFollowCountsView] Followers count: \(profile.followersCount), loading: \(profile.isFollowersLoading)")
                            }
                    }
                    Text("Followers")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .sheet(isPresented: $showingFollowers) {
                FollowersListView()
                    .environmentObject(profile)
                    .environmentObject(userProfileViewModel)
                    .environmentObject(dataManager)
                    .environmentObject(userSession)
            }
            
            // Following count
            Button(action: {
                showingFollowing = true
            }) {
                VStack {
                    if profile.isFollowingLoading {
                        ProgressView()
                            .frame(width: 20, height: 20)
                    } else {
                        Text("\(profile.followingCount)")
                            .font(.headline)
                            .foregroundColor(.black)
                            .fontWeight(.regular)
                            .id("following_\(refreshToggle)")
                    }
                    Text("Following")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .sheet(isPresented: $showingFollowing) {
                FollowingListView()
                    .environmentObject(profile)
                    .environmentObject(userProfileViewModel)
                    .environmentObject(dataManager)
                    .environmentObject(userSession)
            }
            
            // My Places count
            Button(action: {
                showingMyPlaces = true
            }) {
                VStack {
                    if profile.isMyPlacesLoading {
                        ProgressView()
                            .frame(width: 20, height: 20)
                    } else {
                        Text("\(totalMyPlacesCount)")
                            .font(.headline)
                            .foregroundColor(.black)
                            .fontWeight(.regular)
                            .id("myPlaces_\(refreshToggle)")
                    }
                    Text("My Places")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .sheet(isPresented: $showingMyPlaces) {
                MyPlacesListView()
                    .environmentObject(profile)
                    .environmentObject(userProfileViewModel)
                    .environmentObject(dataManager)
                    .environmentObject(userSession)
                    .environmentObject(selectedPlaceVM)
            }
        }
        .padding(.vertical, 10)
        .onChange(of: profile.userFollowing.count) {
            refreshToggle.toggle()
        }
        .onChange(of: profile.userFollowers.count) {
            refreshToggle.toggle()
        }
        .onChange(of: totalMyPlacesCount) {
            refreshToggle.toggle()
        }
    }
} 
