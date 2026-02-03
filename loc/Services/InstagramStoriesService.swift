//
//  InstagramStoriesService.swift
//  loc
//
//  Created by Claude on 1/31/25.
//

import UIKit

/// Service for sharing content directly to Instagram Stories with link stickers.
class InstagramStoriesService {

    /// App bundle identifier used as source application for Instagram.
    private var appBundleID: String {
        Bundle.main.bundleIdentifier ?? "com.drewharts.loc"
    }

    /// Checks if Instagram is installed on the device.
    var isInstagramInstalled: Bool {
        guard let url = URL(string: "instagram-stories://share") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    /// Shares an image to Instagram Stories.
    @MainActor
    func shareToInstagramStories(
        backgroundImage: UIImage,
        stickerImage: UIImage? = nil,
        contentURL: URL? = nil
    ) -> Bool {
        guard isInstagramInstalled else {
            print("❌ [InstagramStoriesService] Instagram is not installed")
            return false
        }

        guard let urlScheme = URL(string: "instagram-stories://share?source_application=\(appBundleID)") else {
            print("❌ [InstagramStoriesService] Failed to create URL scheme")
            return false
        }

        // Prepare pasteboard items
        var pasteboardItems: [[String: Any]] = []
        var items: [String: Any] = [:]

        // Background image (required)
        if let imageData = backgroundImage.pngData() {
            items["com.instagram.sharedSticker.backgroundImage"] = imageData
        }

        // Sticker image (optional - Mesa logo)
        if let sticker = stickerImage, let stickerData = sticker.pngData() {
            items["com.instagram.sharedSticker.stickerImage"] = stickerData
        }

        // Content URL - This becomes the clickable link sticker!
        if let url = contentURL {
            items["com.instagram.sharedSticker.contentURL"] = url.absoluteString
        }

        pasteboardItems.append(items)

        // Set pasteboard with expiration
        let pasteboardOptions: [UIPasteboard.OptionsKey: Any] = [
            .expirationDate: Date().addingTimeInterval(60 * 5) // 5 minutes
        ]

        UIPasteboard.general.setItems(pasteboardItems, options: pasteboardOptions)

        // Open Instagram Stories
        UIApplication.shared.open(urlScheme, options: [:]) { success in
            if success {
                print("✅ [InstagramStoriesService] Opened Instagram Stories")
            } else {
                print("❌ [InstagramStoriesService] Failed to open Instagram Stories")
            }
        }

        return true
    }
}
