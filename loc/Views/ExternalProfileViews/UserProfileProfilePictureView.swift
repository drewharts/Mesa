//
//  UserProfileProfilePictureView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/29/25.
//

import SwiftUI

struct UserProfileProfilePictureView: View {
    let profilePhotoURL: URL?
    let isFollowing: Bool
    let onToggleFollow: () -> Void

    var body: some View {
        let profileImage: some View = Group {
            if let profilePhotoURL = profilePhotoURL {
                AsyncImage(url: profilePhotoURL) { image in
                    image.resizable()
                        .scaledToFill()
                } placeholder: {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .foregroundColor(.gray)
                }
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundColor(.gray)
            }
        }

        profileImage
            .frame(width: 120, height: 120)
            .clipShape(Circle())
            .shadow(radius: 4)
            .overlay(alignment: .topTrailing) {
                Button(action: onToggleFollow) {
                    Image(systemName: isFollowing ? "person.fill.checkmark" : "person.fill.badge.plus")
                        .padding(6)
                        .background(isFollowing ? Color.green : Color.gray)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
                .padding(4)
            }
            .padding(.top, 40)
    }
}
