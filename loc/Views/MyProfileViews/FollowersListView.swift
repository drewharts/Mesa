//
//  FollowersListView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/16/24.
//

import SwiftUI
import UIKit

struct FollowersListView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var userSession: UserSession
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                if profile.isFollowersListLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if profile.userFollowers.isEmpty {
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
                        ForEach(profile.userFollowers) { user in
                            UserRow(user: user)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Followers")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                print("📱 [FollowersListView] Sheet appeared - triggering follower load")
                // Trigger follower loading when sheet appears
                if profile.userFollowers.isEmpty && !profile.isFollowersListLoading {
                    print("👥 [FollowersListView] Starting follower load...")
                    Task {
                        await dataManager.loadFollowers(userId: userSession.currentUserId ?? "")
                    }
                } else {
                    print("👥 [FollowersListView] Skipping load - already loaded or loading")
                }
            }
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
