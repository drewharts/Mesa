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
    @EnvironmentObject var detailPlaceVM: DetailPlaceViewModel
    @State private var showingFollowers = false
    @State private var showingFollowing = false
    @State private var showingMyPlaces = false
    @State private var refreshToggle = false
    
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
                    .environmentObject(detailPlaceVM)
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
                    .environmentObject(detailPlaceVM)
            }
            
            // My Places count (Created places only)
            Button(action: {
                showingMyPlaces = true
            }) {
                VStack {
                    if profile.isMyPlacesLoading {
                        ProgressView()
                            .frame(width: 20, height: 20)
                    } else {
                        Text("\(profile.myPlaces.count)")
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
        .onAppear {
            let userId = userSession.currentUserId ?? ""
            // CRITICAL: Use Task.detached to run on separate thread, not blocked by main thread
            Task.detached(priority: .userInitiated) { [dataManager] in
                await dataManager.loadProfileCounts(userId: userId)
            }
        }
        .onChange(of: profile.userFollowing.count) {
            refreshToggle.toggle()
        }
        .onChange(of: profile.userFollowers.count) {
            refreshToggle.toggle()
        }
        .onChange(of: profile.myPlaces.count) {
            refreshToggle.toggle()
        }
    }
} 
