//
//  PhotoItem.swift
//  loc
//
//  Model representing a photo or video URL for display in galleries.
//

import Foundation

/// Represents a media URL for display in galleries. Supports both photos and videos.
struct PhotoItem: Identifiable, Equatable {
    let id: String
    let url: String
    let isVideo: Bool
    let videoUrl: String?

    /// Creates a photo item from an image URL.
    init(url: String) {
        self.id = url
        self.url = url
        self.isVideo = false
        self.videoUrl = nil
    }

    /// Creates a video item with an optional thumbnail URL.
    init(videoUrl: String, thumbnailUrl: String?) {
        self.id = videoUrl
        self.url = thumbnailUrl ?? ""
        self.isVideo = true
        self.videoUrl = videoUrl
    }
}
