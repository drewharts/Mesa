//
//  ProfileFollowCountsView.swift
//  loc
//
//  Created by Claude on 1/27/25.
//
//  Unified follow counts view that works for both current user profile and external profiles.
//  Uses closures for navigation to support different navigation patterns.
//

import SwiftUI

/// Data model for profile follow counts display.
struct ProfileFollowCountsData {
    let followersCount: Int
    let followingCount: Int
    let myPlacesCount: Int?
    let isFollowersLoading: Bool
    let isFollowingLoading: Bool
    let isMyPlacesLoading: Bool

    /// Creates data for external profiles (no My Places).
    static func external(followers: Int, following: Int) -> ProfileFollowCountsData {
        ProfileFollowCountsData(
            followersCount: followers,
            followingCount: following,
            myPlacesCount: nil,
            isFollowersLoading: false,
            isFollowingLoading: false,
            isMyPlacesLoading: false
        )
    }

    /// Creates data for current user profile with loading states.
    static func myProfile(
        followers: Int,
        following: Int,
        myPlaces: Int,
        isFollowersLoading: Bool,
        isFollowingLoading: Bool,
        isMyPlacesLoading: Bool
    ) -> ProfileFollowCountsData {
        ProfileFollowCountsData(
            followersCount: followers,
            followingCount: following,
            myPlacesCount: myPlaces,
            isFollowersLoading: isFollowersLoading,
            isFollowingLoading: isFollowingLoading,
            isMyPlacesLoading: isMyPlacesLoading
        )
    }
}

/// Displays clickable follower, following, and optionally My Places counts.
struct ProfileFollowCountsView: View {
    let data: ProfileFollowCountsData
    let onFollowersTap: () -> Void
    let onFollowingTap: () -> Void
    let onMyPlacesTap: (() -> Void)?

    @State private var refreshToggle = false

    var body: some View {
        HStack(spacing: 24) {
            followersButton
            followingButton

            if let myPlacesCount = data.myPlacesCount {
                myPlacesButton(count: myPlacesCount)
            }
        }
        .padding(.vertical, 10)
    }

    private var followersButton: some View {
        Button(action: onFollowersTap) {
            VStack {
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

    private var followingButton: some View {
        Button(action: onFollowingTap) {
            VStack {
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

    /// Creates the My Places button for current user profile.
    private func myPlacesButton(count: Int) -> some View {
        Button(action: { onMyPlacesTap?() }) {
            VStack {
                if data.isMyPlacesLoading {
                    ProgressView()
                        .frame(width: 20, height: 20)
                } else {
                    Text("\(count)")
                        .font(.headline)
                        .foregroundColor(.black)
                        .fontWeight(.regular)
                        .id("myPlaces_\(refreshToggle)")
                }
                Text("My Places")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}
