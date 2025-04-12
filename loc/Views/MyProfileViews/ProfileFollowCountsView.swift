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
    @State private var showingFollowers = false
    @State private var showingFollowing = false
    @State private var refreshToggle = false
    
    var body: some View {
        HStack(spacing: 24) {
            // Followers count
            Button(action: {
                showingFollowers = true
            }) {
                VStack {
                    Text("\(profile.followers)")
                        .font(.headline)
                        .foregroundColor(.black)
                        .fontWeight(.regular)
                        .id("followers_\(refreshToggle)")

                    Text("Followers")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .sheet(isPresented: $showingFollowers) {
                FollowersListView()
                    .environmentObject(userProfileViewModel)
            }
            
            // Following count
            Button(action: {
                showingFollowing = true
            }) {
                VStack {
                    Text("\(profile.following)")
                        .font(.headline)
                        .foregroundColor(.black)
                        .fontWeight(.regular)
                        .id("following_\(refreshToggle)")
                    
                    Text("Following")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .sheet(isPresented: $showingFollowing) {
                FollowingListView()
                    .environmentObject(userProfileViewModel)
            }
        }
        .padding(.vertical, 10)
        .onChange(of: profile.following) { _ in
            refreshToggle.toggle()
        }
        .onChange(of: profile.followers) { _ in
            refreshToggle.toggle()
        }
    }
} 
