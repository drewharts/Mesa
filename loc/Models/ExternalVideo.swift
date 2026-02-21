import Foundation
import SwiftUI

struct ExternalVideo: Codable, Identifiable, Equatable {
    var id = UUID()
    let videoID: String
    let url: String
    let title: String?
    let caption: String?
    let embedHTML: String
    var thumbnailURL: String
    let author: ExternalVideoAuthor
    let hashtags: [String]
    let createdAt: String  // Changed from Date to String to match backend
    let contentType: String // "video" or "photo" — defaults to "video" for backward compatibility

    // Ownership tracking (not stored in backend, populated at runtime)
    var savedByUserId: String?
    var externalPlaceId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case videoID = "video_id"
        case url
        case title
        case caption
        case embedHTML = "embed_html"
        case thumbnailURL = "thumbnail_url"
        case author
        case hashtags
        case createdAt = "created_at"
        case contentType = "content_type"
    }

    /// Initializes an ExternalVideo with all properties.
    init(id: UUID = UUID(), videoID: String, url: String, title: String?, caption: String?, embedHTML: String, thumbnailURL: String, author: ExternalVideoAuthor, hashtags: [String], createdAt: String, contentType: String = "video", savedByUserId: String? = nil, externalPlaceId: String? = nil) {
        self.id = id
        self.videoID = videoID
        self.url = url
        self.title = title
        self.caption = caption
        self.embedHTML = embedHTML
        self.thumbnailURL = thumbnailURL
        self.author = author
        self.hashtags = hashtags
        self.createdAt = createdAt
        self.contentType = contentType
        self.savedByUserId = savedByUserId
        self.externalPlaceId = externalPlaceId
    }

    /// Decodes an ExternalVideo from backend JSON format.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Generate a UUID for the id if not present
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()

        self.videoID = try container.decode(String.self, forKey: .videoID)
        self.url = try container.decode(String.self, forKey: .url)
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.caption = try container.decodeIfPresent(String.self, forKey: .caption) ?? ""
        self.embedHTML = try container.decodeIfPresent(String.self, forKey: .embedHTML) ?? ""
        self.thumbnailURL = try container.decodeIfPresent(String.self, forKey: .thumbnailURL) ?? ""
        self.author = try container.decode(ExternalVideoAuthor.self, forKey: .author)
        self.hashtags = try container.decodeIfPresent([String].self, forKey: .hashtags) ?? []
        self.contentType = try container.decodeIfPresent(String.self, forKey: .contentType) ?? "video"

        // Handle date as string
        if let dateString = try container.decodeIfPresent(String.self, forKey: .createdAt) {
            self.createdAt = dateString
        } else {
            // Default to current date string if not provided
            let formatter = ISO8601DateFormatter()
            self.createdAt = formatter.string(from: Date())
        }

        // Ownership tracking not decoded from JSON (populated at runtime)
        self.savedByUserId = nil
        self.externalPlaceId = nil
    }
} 