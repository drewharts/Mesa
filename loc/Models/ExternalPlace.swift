//
//  ExternalPlace.swift
//  loc
//
//  Created by Assistant on current date
//

import Foundation
import FirebaseFirestore

// MARK: - ExternalPlace Models
struct ExternalPlace: Codable, Identifiable {
    let id: String // Document ID from Firebase
    let addedAt: Date
    let address: String
    let coordinates: ExternalPlaceCoordinates
    let name: String
    let placeId: String
    let source: String
    let tiktokVideos: [ExternalTikTokVideo]
    
    enum CodingKeys: String, CodingKey {
        case id
        case addedAt
        case address
        case coordinates
        case name
        case placeId
        case source
        case tiktokVideos
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Document ID will be set separately when fetching from Firebase
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.addedAt = try container.decode(Date.self, forKey: .addedAt)
        self.address = try container.decode(String.self, forKey: .address)
        self.coordinates = try container.decode(ExternalPlaceCoordinates.self, forKey: .coordinates)
        self.name = try container.decode(String.self, forKey: .name)
        self.placeId = try container.decode(String.self, forKey: .placeId)
        self.source = try container.decode(String.self, forKey: .source)
        self.tiktokVideos = try container.decode([ExternalTikTokVideo].self, forKey: .tiktokVideos)
    }
    
    // Manual initializer for creating instances with document ID
    init(id: String, addedAt: Date, address: String, coordinates: ExternalPlaceCoordinates, name: String, placeId: String, source: String, tiktokVideos: [ExternalTikTokVideo]) {
        self.id = id
        self.addedAt = addedAt
        self.address = address
        self.coordinates = coordinates
        self.name = name
        self.placeId = placeId
        self.source = source
        self.tiktokVideos = tiktokVideos
    }
}

struct ExternalPlaceCoordinates: Codable {
    let latitude: Double
    let longitude: Double
}

struct ExternalTikTokVideo: Codable, Identifiable {
    var id: String { videoId }
    let author: ExternalTikTokAuthor
    let createdAt: String
    let embedHtml: String
    let hashtags: [String]
    let thumbnailUrl: String
    let url: String
    let videoId: String
    
    enum CodingKeys: String, CodingKey {
        case author
        case createdAt = "created_at"
        case embedHtml = "embed_html"
        case hashtags
        case thumbnailUrl = "thumbnail_url"
        case url
        case videoId = "video_id"
    }
    
    // Convert to the existing TikTokVideo format for compatibility
    func toTikTokVideo() -> TikTokVideo {
        let tikTokAuthor = TikTokAuthor(
            displayName: author.displayName,
            url: "", // Not available in external format
            username: author.username
        )
        
        return TikTokVideo(
            videoID: videoId,
            url: url,
            title: nil, // Not available in external format
            caption: nil, // Not available in external format
            embedHTML: embedHtml,
            thumbnailURL: thumbnailUrl,
            author: tikTokAuthor,
            hashtags: hashtags,
            createdAt: createdAt
        )
    }
}

struct ExternalTikTokAuthor: Codable {
    let displayName: String
    let username: String
    
    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case username
    }
} 