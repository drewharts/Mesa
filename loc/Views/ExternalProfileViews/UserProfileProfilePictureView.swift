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
    let totalPlacesCount: Int
    let userName: String
    
    // MARK: - Constants
    private let profileSize: CGFloat = 120

    var body: some View {
        VStack(spacing: 16) {
            // Profile image with places count badge
            ZStack(alignment: .bottomTrailing) {
                profileImageView
                    .frame(width: profileSize, height: profileSize)
                    .clipShape(Circle())
                    .shadow(radius: 4)
                
                // Places count badge
                if totalPlacesCount > 0 {
                    PlacesCountBadgeView(
                        count: totalPlacesCount,
                        userName: userName,
                        isOwnProfile: false
                    )
                    .offset(x: 4, y: 4)
                }
            }
            
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
    
    // MARK: - Subviews
    
    private var profileImageView: some View {
        Group {
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
    }
}
