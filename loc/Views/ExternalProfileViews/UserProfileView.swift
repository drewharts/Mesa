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
    @State private var showPageIndicators = true
    @State private var fadeOutTimer: Timer?

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
                .environmentObject(UserProfileVM)
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .onChange(of: selectedTab) {
                    // Show indicators and start fade timer when tab changes
                    showPageIndicators = true
                    startFadeOutTimer()
                }
            }
            
            // Page indicator dots closer to the bottom
            VStack {
                Spacer()
                HStack(spacing: 8) {
                    ForEach(0..<2, id: \.self) { index in
                        Circle()
                            .fill(selectedTab == index ? Color.gray : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .opacity(showPageIndicators ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.3), value: showPageIndicators)
                .padding(.bottom, 10) // Even closer to bottom
            }
        }
        .id(refreshToggle) // Force view refresh when toggle changes
        .onAppear {
            UserProfileVM.checkIfFollowing(currentUserId: userId)
            startFadeOutTimer() // Start timer when view appears
        }
        .onDisappear {
            fadeOutTimer?.invalidate() // Clean up timer
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
        }
    }
    
    private func startFadeOutTimer() {
        // Invalidate existing timer
        fadeOutTimer?.invalidate()
        
        // Start new timer for 5 seconds
        fadeOutTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                showPageIndicators = false
            }
        }
    }
}
