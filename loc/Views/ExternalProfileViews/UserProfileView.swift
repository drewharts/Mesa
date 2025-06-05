//
//  UserProfileView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/29/25.
//

import SwiftUI

struct UserProfileView: View {
    let userId: String
    @ObservedObject var UserProfileVM: UserProfileViewModel
    @EnvironmentObject var profileVM: ProfileViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var refreshToggle = false
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Fixed top section - Profile Picture, Name, Followers
                VStack(spacing: 20) {
                    // Profile Picture
                    UserProfileProfilePictureView(
                        profilePhotoURL: UserProfileVM.selectedUser?.profilePhotoURL,
                        isFollowing: UserProfileVM.isFollowing,
                        onToggleFollow: {
                            //TODO: Need to populate user's annotations on the map after following/unfollowing
                            UserProfileVM.toggleFollowUser(currentUserId: userId)
                            profileVM.toggleFollowUser(userId: UserProfileVM.selectedUser!.id)
                            // Force UI refresh
                            refreshToggle.toggle()
                        }
                    )

                    // Name
                    Text(UserProfileVM.selectedUser!.fullName)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                    
                    VStack {
                        Text("\(UserProfileVM.followers)")
                            .foregroundStyle(.black)
                        Text("Followers")
                            .foregroundStyle(.black)
                            .font(.footnote)
                            .fontWeight(.light)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 20)
                
                Divider()
                    .padding(.horizontal, 20)
                
                // Swipeable content section
                TabView(selection: $selectedTab) {
                    // First page - Favorites and Lists
                    ScrollView {
                        VStack(spacing: 20) {
                            //favorites
                            UserProfileFavoritesView(userFavorites: UserProfileVM.userFavorites)
                            
                            Divider()
                                .padding(.horizontal, 20)
                            
                            //place lists
                            UserProfileListsView(viewModel: UserProfileVM, placeLists: UserProfileVM.userLists)

                            Spacer()
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 20)
                    }
                    .tag(0)
                    
                    // Second page - Activity View
                    UserProfileActivityView(UserProfileVM: UserProfileVM)
                        .tag(1)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            
            // Simple page indicator dots at the bottom
            VStack {
                Spacer()
                HStack(spacing: 8) {
                    ForEach(0..<2, id: \.self) { index in
                        Circle()
                            .fill(selectedTab == index ? Color.gray : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .id(refreshToggle) // Force view refresh when toggle changes
        .onAppear {
            UserProfileVM.checkIfFollowing(currentUserId: userId)
        }
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(Color(.systemGray6), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    self.presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                            .aspectRatio(contentMode: .fit)
                            .foregroundColor(.black)
                        Text("Back")
                            .foregroundColor(.black)
                    }
                }
            }
            
            // Add page indicator dots in the navigation bar
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    ForEach(0..<2, id: \.self) { index in
                        Circle()
                            .fill(selectedTab == index ? Color.blue : Color.gray.opacity(0.5))
                            .frame(width: 8, height: 8)
                    }
                }
            }
        }
    }
}
