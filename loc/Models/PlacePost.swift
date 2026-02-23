//
//  PlacePost.swift
//  loc
//
//  Simplified post model for place activity feed
//

import Foundation

struct PlacePost: Codable, Identifiable {
    let id: String
    let userId: String
    let profilePhotoUrl: String
    let userFirstName: String
    let userLastName: String
    let placeId: String
    let placeName: String
    let text: String              // Can be empty if only photos
    let timestamp: Date
    var images: [String]          // Can be empty if only text
    var videoUrls: [String]
    var videoThumbnailUrls: [String]
    var likes: Int
    var commentCount: Int
    let wouldReturn: Bool?        // nil = not specified, true = would go back, false = wouldn't revisit

    /// Merges images and videos into a unified media list for display.
    var allMediaItems: [PostMediaItem] {
        var items: [PostMediaItem] = images.map { PostMediaItem(imageUrl: $0) }
        for (index, videoUrl) in videoUrls.enumerated() {
            let thumbnail = index < videoThumbnailUrls.count ? videoThumbnailUrls[index] : nil
            items.append(PostMediaItem(videoUrl: videoUrl, thumbnailUrl: thumbnail))
        }
        return items
    }

    init(id: String, userId: String, profilePhotoUrl: String, userFirstName: String, userLastName: String, placeId: String, placeName: String, text: String, timestamp: Date, images: [String], videoUrls: [String] = [], videoThumbnailUrls: [String] = [], likes: Int, commentCount: Int = 0, wouldReturn: Bool? = nil) {
        self.id = id
        self.userId = userId
        self.profilePhotoUrl = profilePhotoUrl
        self.userFirstName = userFirstName
        self.userLastName = userLastName
        self.placeId = placeId
        self.placeName = placeName
        self.text = text
        self.timestamp = timestamp
        self.images = images
        self.videoUrls = videoUrls
        self.videoThumbnailUrls = videoThumbnailUrls
        self.likes = likes
        self.commentCount = commentCount
        self.wouldReturn = wouldReturn
    }
}

