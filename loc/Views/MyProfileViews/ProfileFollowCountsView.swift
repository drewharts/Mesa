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
    
    enum SheetType: Identifiable {
        case followers
        case following
        case myPlaces
        case userProfile
        
        var id: Int {
            switch self {
            case .followers: return 0
            case .following: return 1
            case .myPlaces: return 2
            case .userProfile: return 3
            }
        }
    }
    
    @State private var activeSheet: SheetType?
    @State private var refreshToggle = false
    
    var body: some View {
        HStack(spacing: 24) {
            // Followers count
            Button(action: {
                activeSheet = .followers
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
            
            // Following count
            Button(action: {
                activeSheet = .following
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
            
            // My Places count (Created places only)
            Button(action: {
                activeSheet = .myPlaces
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
        }
        .padding(.vertical, 10)
        .sheet(item: $activeSheet) { sheetType in
            switch sheetType {
            case .followers:
                FollowersListView(onSelectUser: {
                    // Replace sheet with user profile
                    activeSheet = .userProfile
                })
                    .environmentObject(profile)
                    .environmentObject(userProfileViewModel)
                    .environmentObject(dataManager)
                    .environmentObject(userSession)
                    .environmentObject(detailPlaceVM)
            case .following:
                FollowingListView(onSelectUser: {
                    // Replace sheet with user profile
                    activeSheet = .userProfile
                })
                    .environmentObject(profile)
                    .environmentObject(userProfileViewModel)
                    .environmentObject(dataManager)
                    .environmentObject(userSession)
                    .environmentObject(detailPlaceVM)
            case .myPlaces:
                MyPlacesListView()
                    .environmentObject(profile)
                    .environmentObject(userProfileViewModel)
                    .environmentObject(dataManager)
                    .environmentObject(userSession)
                    .environmentObject(selectedPlaceVM)
            case .userProfile:
                UserProfileView(
                    userId: userSession.currentUserId ?? "",
                    UserProfileVM: userProfileViewModel
                )
                .environmentObject(profile)
            }
        }
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
