//
//  PhotoItem.swift
//  loc
//
//  Model representing a photo or video URL for display in galleries.
//

import Foundation

/// Indicates whether a photo originated from a user post or an external review.
enum PhotoSource: Equatable {
    case userPost
    case externalReview
}

/// Represents a media URL for display in galleries. Supports both photos and videos.
struct PhotoItem: Identifiable, Equatable {
    let id: String
    let url: String
    let isVideo: Bool
    let videoUrl: String?
    let source: PhotoSource

    /// Creates a photo item from an image URL with default userPost source.
    init(url: String) {
        self.id = url
        self.url = url
        self.isVideo = false
        self.videoUrl = nil
        self.source = .userPost
    }

    /// Creates a photo item from an image URL with an explicit source.
    init(url: String, source: PhotoSource) {
        self.id = url
        self.url = url
        self.isVideo = false
        self.videoUrl = nil
        self.source = source
    }

    /// Creates a video item with an optional thumbnail URL.
    init(videoUrl: String, thumbnailUrl: String?) {
        self.id = videoUrl
        self.url = thumbnailUrl ?? ""
        self.isVideo = true
        self.videoUrl = videoUrl
        self.source = .userPost
    }
}
