//
//  ExploreSuggestedPersonCard.swift
//  loc
//
//  DUMB Component: Instagram-style "Suggested for you" card with a centered avatar,
//  name, secondary line, a full-width Follow button and a dismiss control.
//

import SwiftUI

struct ExploreSuggestedPersonCard: View {
    let profile: ProfileData
    let isFollowing: Bool
    let onFollowTap: () -> Void
    let onProfileTap: () -> Void
    let onDismissTap: () -> Void

    private let cardWidth: CGFloat = 150
    private let avatarSize: CGFloat = 92

    var body: some View {
        VStack(spacing: 6) {
            Button(action: onProfileTap) {
                VStack(spacing: 6) {
                    avatar
                    Text(profile.fullName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)
            followButton
                .padding(.top, 6)
        }
        .padding(.horizontal, 12)
        .padding(.top, 20)
        .padding(.bottom, 12)
        .frame(width: cardWidth)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color(.separator).opacity(0.5), lineWidth: 0.5))
        .overlay(alignment: .topTrailing) { dismissButton }
    }

    // MARK: - Subviews

    private var subtitle: String {
        if let handle = profile.instagramUsername, !handle.isEmpty { return "@\(handle)" }
        return "Suggested for you"
    }

    private var avatar: some View {
        CachedProfileImage(
            url: profile.profilePhotoURL?.absoluteString,
            size: avatarSize,
            fallbackInitial: String(profile.firstName.prefix(1))
        )
    }

    private var followButton: some View {
        Button(action: onFollowTap) {
            Text(isFollowing ? "Following" : "Follow")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isFollowing ? Color.primary : Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isFollowing ? Color(.systemGray5) : Color.mesaAccent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var dismissButton: some View {
        Button(action: onDismissTap) {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(10)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Dismiss suggestion")
    }
}
