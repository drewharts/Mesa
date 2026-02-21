//
//  ExternalOEmbedResponse.swift
//  loc
//
//  External oEmbed API response model
//

import Foundation

/// Response from external oEmbed endpoints (TikTok and Instagram)
struct ExternalOEmbedResponse: Codable {
    let title: String
    let authorName: String
    let authorUniqueId: String
    let thumbnailUrl: String
    let thumbnailWidth: Int
    let thumbnailHeight: Int
    let html: String
    let embedProductId: String
    let embedType: String
    let providerName: String?
    let authorUrl: String?

    enum CodingKeys: String, CodingKey {
        case title
        case authorName = "author_name"
        case authorUniqueId = "author_unique_id"
        case thumbnailUrl = "thumbnail_url"
        case thumbnailWidth = "thumbnail_width"
        case thumbnailHeight = "thumbnail_height"
        case html
        case embedProductId = "embed_product_id"
        case embedType = "embed_type"
        case providerName = "provider_name"
        case authorUrl = "author_url"
    }

    /// Whether this oEmbed response is from Instagram.
    private var isInstagram: Bool {
        providerName?.lowercased() == "instagram" || embedType.hasPrefix("instagram")
    }

    /// Convert oEmbed response to ExternalVideo for compatibility with existing views.
    func toExternalVideo(videoUrl: String) -> ExternalVideo {
        let authorProfileUrl: String
        if isInstagram {
            authorProfileUrl = authorUrl ?? "https://www.instagram.com/\(authorUniqueId)"
        } else {
            authorProfileUrl = authorUrl ?? "https://www.tiktok.com/@\(authorUniqueId)"
        }

        let author = ExternalVideoAuthor(
            displayName: authorName,
            url: authorProfileUrl,
            username: authorUniqueId
        )

        return ExternalVideo(
            videoID: embedProductId,
            url: videoUrl,
            title: title,
            caption: title,
            embedHTML: html,
            thumbnailURL: thumbnailUrl,
            author: author,
            hashtags: [],
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
    }
}
