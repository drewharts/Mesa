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

    var body: some View {
        ScrollView {
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

                Divider()
                    .padding(.horizontal, 20)

                //favorites
                UserProfileFavoritesView(userFavorites: UserProfileVM.userFavorites, placeImages: UserProfileVM.favoritePlaceImages)
                Divider()
                    .padding(.horizontal, 20)
                //place lists
                UserProfileListsView(viewModel: UserProfileVM, placeLists: UserProfileVM.userLists)

                Spacer()
            }
            .padding(.bottom, 20)
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
        }
    }
}
