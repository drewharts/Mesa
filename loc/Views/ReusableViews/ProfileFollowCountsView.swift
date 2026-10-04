//
//  ProfileFollowCountsView.swift
//  loc
//
//  Unified follow counts view that works for both current user profile and external profiles.
//  Displays followers/following/places as three equally-spaced stats. Social links live in
//  the separate ProfileSocialLinksRow so this row stays evenly spaced regardless of whether
//  socials are present.
//
//  Single Responsibility: Display follow/place counts with consistent, evenly-spaced styling.
//

import SwiftUI

/// Data model for profile follow counts display.
struct ProfileFollowCountsData {
    let followersCount: Int
    let followingCount: Int
    /// Total places saved/reviewed/created. Shown as a third stat alongside followers/following
    /// when non-nil, instead of as a separate badge overlaid on the profile photo.
    let placesCount: Int?
    let isFollowersLoading: Bool
    let isFollowingLoading: Bool

    /// Creates data for external profiles.
    static func external(
        followers: Int,
        following: Int,
        places: Int
    ) -> ProfileFollowCountsData {
        ProfileFollowCountsData(
            followersCount: followers,
            followingCount: following,
            placesCount: places,
            isFollowersLoading: false,
            isFollowingLoading: false
        )
    }

    /// Creates data for current user profile with loading states.
    static func myProfile(
        followers: Int,
        following: Int,
        places: Int,
        isFollowersLoading: Bool,
        isFollowingLoading: Bool
    ) -> ProfileFollowCountsData {
        ProfileFollowCountsData(
            followersCount: followers,
            followingCount: following,
            placesCount: places,
            isFollowersLoading: isFollowersLoading,
            isFollowingLoading: isFollowingLoading
        )
    }
}

/// Displays clickable follower/following/places counts, evenly spaced across the row's width.
struct ProfileFollowCountsView: View {
    let data: ProfileFollowCountsData
    let onFollowersTap: () -> Void
    let onFollowingTap: () -> Void
    var hideFollowing: Bool = false

    @State private var refreshToggle = false

    var body: some View {
        HStack(spacing: 0) {
            followersButton.frame(maxWidth: .infinity, alignment: .leading)

            if !hideFollowing {
                followingButton.frame(maxWidth: .infinity, alignment: .leading)
            }

            if data.placesCount != nil {
                placesButton.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 10)
    }

    /// Displays the followers count with loading state. Left-aligned so the count and
    /// label share a leading edge with the user's name above.
    private var followersButton: some View {
        Button(action: onFollowersTap) {
            VStack(alignment: .leading) {
                if data.isFollowersLoading {
                    ProgressView()
                        .frame(width: 20, height: 20)
                } else {
                    Text("\(data.followersCount)")
                        .font(.headline)
                        .foregroundColor(.black)
                        .fontWeight(.regular)
                        .id("followers_\(refreshToggle)")
                }
                Text("Followers")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }

    /// Displays the following count with loading state.
    private var followingButton: some View {
        Button(action: onFollowingTap) {
            VStack(alignment: .leading) {
                if data.isFollowingLoading {
                    ProgressView()
                        .frame(width: 20, height: 20)
                } else {
                    Text("\(data.followingCount)")
                        .font(.headline)
                        .foregroundColor(.black)
                        .fontWeight(.regular)
                        .id("following_\(refreshToggle)")
                }
                Text("Following")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }

    /// Displays the saved places count as a static stat (no navigation target).
    private var placesButton: some View {
        VStack(alignment: .leading) {
            Text("\(data.placesCount ?? 0)")
                .font(.headline)
                .foregroundColor(.black)
                .fontWeight(.regular)
            Text("Places")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}
