//
//  ProfileFollowCountsView.swift
//  loc
//
//  Unified follow counts view that works for both current user profile and external profiles.
//  Displays follower/following counts and optional social link icons.
//
//  Single Responsibility: Display follow counts and social link icons with consistent styling.
//

import SwiftUI

/// Data model for profile follow counts display.
struct ProfileFollowCountsData {
    let followersCount: Int
    let followingCount: Int
    let isFollowersLoading: Bool
    let isFollowingLoading: Bool
    let instagramUsername: String?
    let tiktokUsername: String?

    /// Creates data for external profiles.
    static func external(
        followers: Int,
        following: Int,
        instagramUsername: String?,
        tiktokUsername: String?
    ) -> ProfileFollowCountsData {
        ProfileFollowCountsData(
            followersCount: followers,
            followingCount: following,
            isFollowersLoading: false,
            isFollowingLoading: false,
            instagramUsername: instagramUsername,
            tiktokUsername: tiktokUsername
        )
    }

    /// Creates data for current user profile with loading states.
    static func myProfile(
        followers: Int,
        following: Int,
        isFollowersLoading: Bool,
        isFollowingLoading: Bool,
        instagramUsername: String?,
        tiktokUsername: String?
    ) -> ProfileFollowCountsData {
        ProfileFollowCountsData(
            followersCount: followers,
            followingCount: following,
            isFollowersLoading: isFollowersLoading,
            isFollowingLoading: isFollowingLoading,
            instagramUsername: instagramUsername,
            tiktokUsername: tiktokUsername
        )
    }
}

/// Displays clickable follower/following counts and social link icons.
struct ProfileFollowCountsView: View {
    let data: ProfileFollowCountsData
    let onFollowersTap: () -> Void
    let onFollowingTap: () -> Void
    var hideFollowing: Bool = false
    var onAddSocialsTap: (() -> Void)? = nil

    @State private var refreshToggle = false

    /// Whether the user has a non-empty Instagram username.
    private var hasInstagram: Bool {
        guard let handle = data.instagramUsername else { return false }
        return !handle.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Whether the user has a non-empty TikTok username.
    private var hasTikTok: Bool {
        guard let handle = data.tiktokUsername else { return false }
        return !handle.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Whether the social icons section should be visible.
    private var shouldShowSocialIcons: Bool {
        hasInstagram || hasTikTok || onAddSocialsTap != nil
    }

    var body: some View {
        HStack(spacing: 24) {
            followersButton

            if !hideFollowing {
                followingButton
            }

            if shouldShowSocialIcons {
                socialLinksSection
            }
        }
        .padding(.vertical, 10)
    }

    /// Displays the followers count with loading state.
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

    /// Displays the following count with loading state.
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

    // MARK: - Social Links

    /// Displays Instagram and TikTok social link icon buttons.
    private var socialLinksSection: some View {
        VStack(spacing: 4) {
            HStack(spacing: 28) {
                instagramIcon
                tiktokIcon
            }

            if let onTap = onAddSocialsTap, !hasInstagram && !hasTikTok {
                Button(action: onTap) {
                    Text("Add your socials")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }
        }
    }

    /// Displays the Instagram icon, opening the app/web if set or Edit Profile if empty.
    private var instagramIcon: some View {
        Group {
            if hasInstagram, let handle = data.instagramUsername {
                SocialLinkButton(
                    imageName: "Instagram_Glyph_Black",
                    systemFallback: "camera",
                    appURL: "instagram://user?username=\(handle)",
                    webURL: "https://instagram.com/\(handle)"
                )
            } else if let onTap = onAddSocialsTap {
                Button(action: onTap) {
                    Image("Instagram_Glyph_Black")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                        .opacity(0.3)
                }
            }
        }
    }

    /// Displays the TikTok icon, opening the app/web if set or Edit Profile if empty.
    private var tiktokIcon: some View {
        Group {
            if hasTikTok, let handle = data.tiktokUsername {
                SocialLinkButton(
                    imageName: "tiktok",
                    systemFallback: "music.note",
                    appURL: "https://tiktok.com/@\(handle)",
                    webURL: "https://tiktok.com/@\(handle)"
                )
            } else if let onTap = onAddSocialsTap {
                Button(action: onTap) {
                    Image("tiktok")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                        .opacity(0.3)
                }
            }
        }
    }
}
