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
    @EnvironmentObject var detailPlaceVM: DetailPlaceViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                if profile.userFollowing.isEmpty {
                    if profile.isFollowingListLoading {
                        Spacer()
                        ProgressView()
                        Spacer()
                    } else {
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
                    }
                } else {
                    List {
                        ForEach(profile.userFollowing) { profileData in
                            UserRow(user: profileData)
                                .onAppear {
                                    // Load more when user scrolls to the last few items
                                    if let index = profile.userFollowing.firstIndex(where: { $0.id == profileData.id }),
                                       index >= profile.userFollowing.count - 3 && !profile.isFollowingListLoading {
                                        Task {
                                            await dataManager.loadFollowing(userId: userSession.currentUserId ?? "", offset: profile.userFollowing.count)
                                        }
                                    }
                                }
                        }
                        
                        // Loading indicator at bottom while loading more
                        if profile.isFollowingListLoading {
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
            .navigationTitle("Following")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Always load following profiles when sheet appears
                if !profile.isFollowingListLoading {
                    Task {
                        await dataManager.loadFollowing(userId: userSession.currentUserId ?? "")
                    }
                }
            }
            .sheet(isPresented: $userProfileViewModel.isUserDetailPresented) {
                UserProfileView(
                    userId: userSession.currentUserId ?? "",
                    UserProfileVM: userProfileViewModel
                )
                .environmentObject(profile)
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
