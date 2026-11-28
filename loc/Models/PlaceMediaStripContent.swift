//
//  PlaceMediaStripContent.swift
//  loc
//
//  Merges place photos and videos into the strip's tiles, dropping anything that cannot be shown.
//

import Foundation

struct PlaceMediaStripContent: Equatable {
    /// Maximum number of tiles rendered in the strip.
    static let maxItems: Int = 30

    /// Tiles in display order: videos first, then photos.
    let items: [PlaceMediaStripItem]
    /// Every displayable photo URL, in the order the fullscreen gallery pages through them.
    let photoURLs: [String]

    static let empty: PlaceMediaStripContent = PlaceMediaStripContent(items: [], photoURLs: [])

    /// Builds the strip content, skipping empty or invalid URLs, failed tiles and duplicates
    /// (including photos that are just a video's thumbnail).
    static func make(
        photos: [PhotoItem],
        videos: [ExternalVideo],
        failedIDs: Set<String>,
        maxItems: Int = PlaceMediaStripContent.maxItems
    ) -> PlaceMediaStripContent {
        var seen: Set<String> = []
        var tiles: [PlaceMediaStripItem] = []
        for video in videos {
            guard let tile = externalVideoTile(video, failedIDs: failedIDs), seen.insert(tile.thumbnailURL).inserted else { continue }
            tiles.append(tile)
        }
        var photoURLs: [String] = []
        for photo in photos {
            guard isDisplayable(photo.url), !failedIDs.contains(photo.id) else { continue }
            if photo.isVideo {
                guard let videoURL = photo.videoUrl, isDisplayable(videoURL), seen.insert(photo.url).inserted else { continue }
                tiles.append(PlaceMediaStripItem(id: photo.id, thumbnailURL: photo.url, kind: .galleryVideo(url: videoURL), source: photo.source))
            } else {
                guard seen.insert(photo.url).inserted else { continue }
                tiles.append(PlaceMediaStripItem(id: photo.id, thumbnailURL: photo.url, kind: .photo(galleryIndex: photoURLs.count), source: photo.source))
                photoURLs.append(photo.url)
            }
        }
        return PlaceMediaStripContent(items: Array(tiles.prefix(maxItems)), photoURLs: photoURLs)
    }

    /// Returns a tile for an external video with a usable thumbnail that has not failed to load.
    private static func externalVideoTile(_ video: ExternalVideo, failedIDs: Set<String>) -> PlaceMediaStripItem? {
        let tileID = "video_\(video.videoID)"
        guard isDisplayable(video.thumbnailURL), !failedIDs.contains(tileID) else { return nil }
        return PlaceMediaStripItem(id: tileID, thumbnailURL: video.thumbnailURL, kind: .externalVideo(videoID: video.videoID), source: nil)
    }

    /// Whether the string is a non-blank, parseable URL.
    private static func isDisplayable(_ urlString: String) -> Bool {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && URL(string: trimmed) != nil
    }
}
