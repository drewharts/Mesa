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
            ScrollView {
                VStack(spacing: 0) {
                    // Profile Picture, Name, Followers - now scrollable
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
                    
                    // Content section - now scrollable with the rest
                    VStack(spacing: 0) {
                        // Tab selection buttons
                        HStack(spacing: 40) {
                            Button(action: { selectedTab = 0 }) {
                                VStack(spacing: 4) {
                                    Text("Profile")
                                        .font(.subheadline)
                                        .fontWeight(selectedTab == 0 ? .semibold : .regular)
                                        .foregroundColor(selectedTab == 0 ? .black : .gray)
                                        .frame(minHeight: 20) // Ensure consistent height
                                    
                                    Rectangle()
                                        .fill(selectedTab == 0 ? Color.black : Color.clear)
                                        .frame(width: 50, height: 2) // Shortened width
                                        .animation(.easeInOut(duration: 0.3), value: selectedTab)
                                }
                            }
                            
                            Button(action: { selectedTab = 1 }) {
                                VStack(spacing: 4) {
                                    Text("Reviews")
                                        .font(.subheadline)
                                        .fontWeight(selectedTab == 1 ? .semibold : .regular)
                                        .foregroundColor(selectedTab == 1 ? .black : .gray)
                                        .frame(minHeight: 20) // Ensure consistent height
                                    
                                    Rectangle()
                                        .fill(selectedTab == 1 ? Color.black : Color.clear)
                                        .frame(width: 50, height: 2) // Shortened width
                                        .animation(.easeInOut(duration: 0.3), value: selectedTab)
                                }
                            }
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                        
                        // Content based on selected tab
                        if selectedTab == 0 {
                            VStack(spacing: 20) {
                                //favorites
                                UserProfileFavoritesView(userFavorites: UserProfileVM.userFavorites)
                                
                                Divider()
                                    .padding(.horizontal, 20)
                                
                                //place lists
                                UserProfileListsView(viewModel: UserProfileVM, placeLists: UserProfileVM.userLists)

                                Spacer(minLength: 50)
                            }
                            .padding(.top, 10)
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                        } else {
                            UserProfileActivityView(UserProfileVM: UserProfileVM)
                                .padding(.top, 10)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                        }
                    }
                }
            }
            .environmentObject(UserProfileVM)
            
            // Page indicator dots at the bottom
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
                .padding(.bottom, 10)
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
        .onChange(of: selectedTab) {
            // Show indicators and start fade timer when tab changes
            showPageIndicators = true
            startFadeOutTimer()
        }
        .toolbarBackground(Color(.systemGray6), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Follow Error", isPresented: $UserProfileVM.showFollowError) {
            Button("OK") {
                UserProfileVM.showFollowError = false
            }
        } message: {
            Text(UserProfileVM.followErrorMessage)
        }
        .alert("Follow Error", isPresented: $profileVM.showFollowError) {
            Button("OK") {
                profileVM.showFollowError = false
            }
        } message: {
            Text(profileVM.followErrorMessage)
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
