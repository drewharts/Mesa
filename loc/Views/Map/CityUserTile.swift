//
//  CityUserTile.swift
//  loc
//
//  Tile view for an active user in the city detail horizontal scroll row.
//  Uses image-background + gradient overlay to match CityPlaceTile style.
//

import SwiftUI

/// Square tile displaying a user's profile photo as background with gradient overlay text.
struct CityUserTile: View {
    let user: CityActiveUser
    let isFollowing: Bool
    let isCurrentUser: Bool
    let onTap: () -> Void
    let onFollow: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                background
                gradientOverlay

                VStack(alignment: .leading, spacing: 2) {
                    Text(user.fullName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }
                .padding(10)
            }
            .frame(width: 140, height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .topTrailing) {
                followPill
            }
            .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Subtitle

    /// Formatted subtitle showing list and place counts.
    private var subtitle: String {
        let lists = "\(user.listCount) list\(user.listCount == 1 ? "" : "s")"
        let places = "\(user.placeCount) place\(user.placeCount == 1 ? "" : "s")"
        return "\(lists) · \(places)"
    }

    // MARK: - Background

    /// Profile photo filling the entire tile or gradient fallback with initials.
    @ViewBuilder
    private var background: some View {
        if let urlString = user.profilePhotoUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 140, height: 140)
                    .clipped()
            } placeholder: {
                initialsFallback
            }
        } else {
            initialsFallback
        }
    }

    /// Gradient overlay for readability over the background image.
    private var gradientOverlay: some View {
        LinearGradient(
            colors: [.clear, .black.opacity(0.6)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Gradient background with centered initials when no photo is available.
    private var initialsFallback: some View {
        LinearGradient(
            colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(width: 140, height: 140)
        .overlay(
            Text(initials)
                .font(.system(size: 36))
                .fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.9))
        )
    }

    // MARK: - Follow Pill

    /// Compact follow/following capsule pill overlaid at top-right.
    @ViewBuilder
    private var followPill: some View {
        if !isCurrentUser {
            Button(action: onFollow) {
                Text(isFollowing ? "Following" : "Follow")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isFollowing ? Color.black.opacity(0.3) : Color.blue)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(6)
        }
    }

    // MARK: - Initials

    /// Computes initials from the user's full name.
    private var initials: String {
        let parts = user.fullName.split(separator: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last = parts.count > 1 ? parts.last!.prefix(1) : ""
        return "\(first)\(last)".uppercased()
    }
}
