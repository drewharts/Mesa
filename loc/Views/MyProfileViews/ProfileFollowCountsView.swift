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
    }
} 