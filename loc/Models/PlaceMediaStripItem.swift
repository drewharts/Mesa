//
//  PlaceMediaStripItem.swift
//  loc
//
//  One tile in the place detail media strip: a photo or a video (with a play badge).
//

import Foundation

struct PlaceMediaStripItem: Identifiable, Equatable {
    /// What tapping the tile opens.
    enum Kind: Equatable {
        /// Photo shown in the fullscreen gallery at `galleryIndex` of `PlaceMediaStripContent.photoURLs`.
        case photo(galleryIndex: Int)
        /// Gallery video played in the fullscreen player.
        case galleryVideo(url: String)
        /// External (TikTok etc.) video identified by `ExternalVideo.videoID`.
        case externalVideo(videoID: String)
    }

    let id: String
    let thumbnailURL: String
    let kind: Kind
    /// Source of the underlying photo, used to decide whether it can be deleted.
    let source: PhotoSource?

    /// Whether the tile shows a play badge.
    var isVideo: Bool {
        if case .photo = kind { return false }
        return true
    }
}
