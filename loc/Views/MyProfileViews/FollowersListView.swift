//
//  FollowersListView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/16/24.
//

import SwiftUI
import UIKit

struct FollowersListView: View {
    let onSelectUser: () -> Void
    
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var detailPlaceVM: DetailPlaceViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                if profile.userFollowers.isEmpty {
                    if profile.isFollowersListLoading {
                        Spacer()
                        ProgressView()
                        Spacer()
                    } else {
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
                    }
                } else {
                    List {
                        ForEach(profile.userFollowers) { user in
                            UserRow(user: user, onSelectUser: onSelectUser)
                                .onAppear {
                                    // Load more when user scrolls to the last few items
                                    if let index = profile.userFollowers.firstIndex(where: { $0.id == user.id }),
                                       index >= profile.userFollowers.count - 3 && !profile.isFollowersListLoading {
                                        Task {
                                            await dataManager.loadFollowers(userId: userSession.currentUserId ?? "", offset: profile.userFollowers.count)
                                        }
                                    }
                                }
                        }
                        
                        // Loading indicator at bottom while loading more
                        if profile.isFollowersListLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .padding()
                                Spacer()
                            }
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Followers")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Always load follower profiles when sheet appears
                if !profile.isFollowersListLoading {
                    Task {
                        await dataManager.loadFollowers(userId: userSession.currentUserId ?? "")
                    }
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
