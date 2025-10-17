//
//  FollowingListView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/16/24.
//

import SwiftUI
import UIKit

struct FollowingListView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var userSession: UserSession
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                if profile.isFollowingListLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if profile.userFollowing.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Text("Not Following Anyone Yet")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)
                        
                        Text("When you follow someone, they'll appear here.")
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(profile.userFollowing) { profileData in
                            UserRow(user: profileData)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Following")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                print("📱 [FollowingListView] Sheet appeared - triggering following load")
                // Trigger following loading when sheet appears
                if profile.userFollowing.isEmpty && !profile.isFollowingListLoading {
                    print("👥 [FollowingListView] Starting following load...")
                    Task {
                        await dataManager.loadFollowing(userId: userSession.currentUserId ?? "")
                    }
                } else {
                    print("👥 [FollowingListView] Skipping load - already loaded or loading")
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
