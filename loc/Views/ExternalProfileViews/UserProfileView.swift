//
//  UserProfileView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/29/25.
//

import SwiftUI

struct UserProfileView: View {
    let userId: String
    @ObservedObject var viewModel: UserProfileViewModel
    @EnvironmentObject var profile: ProfileViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var refreshToggle = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Profile Picture
                UserProfileProfilePictureView(
                    profilePhotoURL: viewModel.selectedUser?.profilePhotoURL,
                    isFollowing: viewModel.isFollowing,
                    onToggleFollow: {
                        viewModel.toggleFollowUser(currentUserId: userId)
                        profile.toggleFollowUser(userId: viewModel.selectedUser!.id)
                        // Force UI refresh
                        refreshToggle.toggle()
                    }
                )

                // Name
                Text(viewModel.selectedUser!.fullName)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                VStack {
                    Text("\(viewModel.followers)")
                        .foregroundStyle(.black)
                    Text("Followers")
                        .foregroundStyle(.black)
                        .font(.footnote)
                        .fontWeight(.light)
                }

                Divider()
                    .padding(.horizontal, 20)

                //favorites
                UserProfileFavoritesView(userFavorites: viewModel.userFavorites, placeImages: viewModel.favoritePlaceImages)
                Divider()
                    .padding(.horizontal, 20)
                //place lists
                UserProfileListsView(viewModel: viewModel, placeLists: viewModel.userLists)

                Spacer()
            }
            .padding(.bottom, 20)
        }
        .id(refreshToggle) // Force view refresh when toggle changes
        .onAppear {
            viewModel.checkIfFollowing(currentUserId: userId)
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
}
