//
//  FollowersListView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/16/24.
//

import SwiftUI
import UIKit

struct UserRow: View {
    @EnvironmentObject var profile: ProfileViewModel
    let user: ProfileData
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    
    var body: some View {
        Button(action: {
            userProfileViewModel.selectUser(user, currentUserId: profile.userId)
        }) {
            HStack(spacing: 12) {
                // User profile photo
                if let profileImage = profile.profilePhoto(forUserId: user.id) {
                    Image(uiImage: profileImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .foregroundColor(Color(.systemGray5))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Text(user.fullName.prefix(1))
                                .foregroundColor(.gray)
                        )
                }
                
                // User name
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.fullName)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    // Additional user info could go here in the future
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.footnote)
            }
            .padding(.vertical, 8)
        }
        .contentShape(Rectangle())
    }
}

struct FollowersListView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                if profile.followerProfiles.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Text("No Followers Yet")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)
                        
                        Text("When someone follows you, they'll appear here.")
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(profile.followerProfiles) { user in
                            UserRow(user: user)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Followers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }
} 
