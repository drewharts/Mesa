//
//  ProfileSocialLinksRow.swift
//  loc
//
//  Standalone Instagram/TikTok quick-link row for a profile header, shown inline next to
//  the user's name so the followers/following/places stats row below stays evenly spaced.
//
//  Single Responsibility: Display social link icons with consistent styling.
//

import SwiftUI

/// Displays Instagram and TikTok quick-link icons for a profile, tappable to open Edit
/// Profile on the current user's own profile when neither is set.
struct ProfileSocialLinksRow: View {
    let instagramUsername: String?
    let tiktokUsername: String?
    var onAddSocialsTap: (() -> Void)? = nil

    /// Whether the user has a non-empty Instagram username.
    private var hasInstagram: Bool {
        guard let handle = instagramUsername else { return false }
        return !handle.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Whether the user has a non-empty TikTok username.
    private var hasTikTok: Bool {
        guard let handle = tiktokUsername else { return false }
        return !handle.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var shouldShow: Bool {
        hasInstagram || hasTikTok || onAddSocialsTap != nil
    }

    var body: some View {
        if shouldShow {
            HStack(spacing: 14) {
                instagramIcon
                tiktokIcon
            }
        }
    }

    /// Displays the Instagram icon, opening the app/web if set or Edit Profile if empty.
    @ViewBuilder
    private var instagramIcon: some View {
        if hasInstagram, let handle = instagramUsername {
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

    /// Displays the TikTok icon, opening the app/web if set or Edit Profile if empty.
    @ViewBuilder
    private var tiktokIcon: some View {
        if hasTikTok, let handle = tiktokUsername {
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
