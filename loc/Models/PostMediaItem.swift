//
//  PostMediaItem.swift
//  loc
//
//  Unified media item for displaying photos and videos in post feeds
//

import Foundation

enum PostMediaType: String, Codable {
    case image
    case video
}

struct PostMediaItem: Identifiable {
    let id: String
    let url: String
    let type: PostMediaType
    let thumbnailUrl: String?

    /// Creates a media item from an image URL.
    init(imageUrl: String) {
        self.id = imageUrl
        self.url = imageUrl
        self.type = .image
        self.thumbnailUrl = nil
    }

    /// Creates a media item from a video URL with an optional thumbnail.
    init(videoUrl: String, thumbnailUrl: String?) {
        self.id = videoUrl
        self.url = videoUrl
        self.type = .video
        self.thumbnailUrl = thumbnailUrl
    }
}
