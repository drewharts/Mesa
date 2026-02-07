//
//  SocialLinksColumn.swift
//  loc
//
//  Displays tappable social media icons (Instagram, TikTok) in a vertical stack.
//  Designed to sit next to the profile picture. Renders nothing if both handles are nil or empty.
//

import SwiftUI

/// A vertical column of tappable social link icons placed beside the profile picture
struct SocialLinksColumn: View {
    let instagramUsername: String?
    let tiktokUsername: String?

    private var hasInstagram: Bool {
        guard let handle = instagramUsername else { return false }
        return !handle.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var hasTikTok: Bool {
        guard let handle = tiktokUsername else { return false }
        return !handle.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        if hasInstagram || hasTikTok {
            VStack(spacing: 12) {
                if hasInstagram, let handle = instagramUsername {
                    socialButton(
                        imageName: "instagram_icon",
                        systemFallback: "camera",
                        appURL: "instagram://user?username=\(handle)",
                        webURL: "https://instagram.com/\(handle)"
                    )
                }
                if hasTikTok, let handle = tiktokUsername {
                    socialButton(
                        imageName: "tiktok_icon",
                        systemFallback: "music.note",
                        appURL: "tiktok://user?username=\(handle)",
                        webURL: "https://tiktok.com/@\(handle)"
                    )
                }
            }
        }
    }

    /// Creates a tappable social media icon button
    private func socialButton(
        imageName: String,
        systemFallback: String,
        appURL: String,
        webURL: String
    ) -> some View {
        Button {
            openSocialLink(appURL: appURL, webURL: webURL)
        } label: {
            Group {
                if UIImage(named: imageName) != nil {
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: systemFallback)
                }
            }
            .frame(width: 20, height: 20)
            .foregroundColor(.gray)
        }
    }

    /// Opens the app deep link, falling back to the web URL
    private func openSocialLink(appURL: String, webURL: String) {
        guard let app = URL(string: appURL) else { return }
        if UIApplication.shared.canOpenURL(app) {
            UIApplication.shared.open(app)
        } else if let web = URL(string: webURL) {
            UIApplication.shared.open(web)
        }
    }
}
