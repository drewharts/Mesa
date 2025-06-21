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
        VStack(spacing: 16) {
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
            
            Button(action: onToggleFollow) {
                Text(isFollowing ? "Following" : "Follow")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isFollowing ? .primary : .white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isFollowing ? Color(.systemGray5) : Color.blue)
                    )
            }
        }
        .padding(.top, 40)
    }
}
