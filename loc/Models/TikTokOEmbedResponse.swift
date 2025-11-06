//
//  TikTokOEmbedResponse.swift
//  loc
//
//  TikTok oEmbed API response model
//

import Foundation

/// Response from the TikTok oEmbed endpoint
struct TikTokOEmbedResponse: Codable {
    let title: String
    let authorName: String
    let authorUniqueId: String
    let thumbnailUrl: String
    let thumbnailWidth: Int
    let thumbnailHeight: Int
    let html: String
    let embedProductId: String
    let embedType: String
    
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
    }
    
    /// Convert oEmbed response to TikTokVideo for compatibility with existing views
    func toTikTokVideo(videoUrl: String) -> TikTokVideo {
        let author = TikTokAuthor(
            displayName: authorName,
            url: "https://www.tiktok.com/@\(authorUniqueId)",
            username: authorUniqueId
        )
        
        return TikTokVideo(
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

