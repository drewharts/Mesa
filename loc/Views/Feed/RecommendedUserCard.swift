//
//  RecommendedUserCard.swift
//  loc
//
//  DUMB Component: A single user card for the recommended users horizontal scroll.
//  Single Responsibility: Display one recommended user with follow action.
//

import SwiftUI

struct RecommendedUserCard: View {
    let profile: ProfileData
    let isFollowing: Bool
    let onFollowTap: () -> Void
    let onProfileTap: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            profileImage
            nameLabel
            followButton
        }
        .frame(width: 140)
        .onTapGesture {
            onProfileTap()
        }
    }

    // MARK: - Subviews

    private var profileImage: some View {
        CachedProfileImage(
            url: profile.profilePhotoURL?.absoluteString,
            size: 72,
            fallbackInitial: String(profile.firstName.prefix(1))
        )
    }

    private var nameLabel: some View {
        Text(profile.fullName)
            .font(.subheadline)
            .fontWeight(.medium)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .frame(height: 36)
    }

    private var followButton: some View {
        Button {
            onFollowTap()
        } label: {
            Text(isFollowing ? "Following" : "Follow")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(isFollowing ? .secondary : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isFollowing ? Color(.systemGray5) : Color.blue)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
