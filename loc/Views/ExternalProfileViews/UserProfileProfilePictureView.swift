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

    @State private var showingPlacesCount = false
    @State private var showingFullScreen = false

    var body: some View {
        VStack(spacing: 16) {
            // Profile image with places count badge
            ZStack(alignment: .bottomTrailing) {
                profileImageView
                    .frame(width: profileSize, height: profileSize)
                    .clipShape(Circle())
                    .shadow(radius: 4)
                    .onTapGesture {
                        if profilePhotoURL != nil {
                            showingFullScreen = true
                        }
                    }

                // Places count badge (bottom-trailing)
                if totalPlacesCount > 0 {
                    ProfileStatBadge(count: totalPlacesCount) {
                        showingPlacesCount = true
                    }
                    .offset(x: 4, y: 0)
                }
            }
            .frame(width: profileSize + 24, height: profileSize + 8)

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
        .padding(.top, 0)
        .alert("Places Saved", isPresented: $showingPlacesCount) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("\(userName) has \(totalPlacesCount) places saved across all their lists, favorites, and reviews.")
        }
        .fullScreenCover(isPresented: $showingFullScreen) {
            fullScreenPhoto
        }
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

    @ViewBuilder
    private var fullScreenPhoto: some View {
        if let url = profilePhotoURL {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)

                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .padding()
                } placeholder: {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }

                VStack {
                    HStack {
                        Spacer()
                        Button {
                            showingFullScreen = false
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundColor(.white)
                                .padding()
                        }
                    }
                    Spacer()
                }
            }
        }
    }
}
