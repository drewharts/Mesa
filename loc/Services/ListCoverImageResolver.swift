//
//  ListCoverImageResolver.swift
//  loc
//
//  Single Responsibility: Decide which image URLs a list cover may show, in priority order,
//  so the cover can fall back to the next image (or the next place) when one fails to load.
//

import Foundation

enum ListCoverImageResolver {

    /// Storage file name used for share-card uploads; legacy uploads stored the card as `cover.jpg` in the `list_covers` bucket.
    static let shareCardFileName = "share-card.jpg"

    /// Returns true when the URL points at a generated share-card upload rather than a user-chosen cover.
    static func isShareCardURL(_ urlString: String) -> Bool {
        guard urlString.contains("/list_covers/") else { return false }
        let path = urlString.split(separator: "?").first.map(String.init) ?? urlString
        return path.hasSuffix("/cover.jpg") || path.hasSuffix("/\(shareCardFileName)")
    }

    /// Returns the list's own cover URL, or nil when it is empty or is a generated share card.
    static func customCoverURL(_ urlString: String?) -> String? {
        guard let trimmed = urlString?.trimmingCharacters(in: .whitespaces),
              !trimmed.isEmpty, !isShareCardURL(trimmed) else { return nil }
        return trimmed
    }

    /// Returns de-duplicated, non-empty candidate image URLs: server preview photos first, then each place's video thumbnail, review photo, and place thumbnail.
    static func candidateURLs(
        previewPhotos: [String]?,
        places: [LightweightPlace],
        videoThumbnail: (String) -> String?
    ) -> [String] {
        let previewURLs: [String?] = (previewPhotos ?? []).map { $0 }
        let placeURLs: [String?] = places.flatMap { place -> [String?] in
            [
                place.content_url.flatMap(videoThumbnail),
                place.latest_review_photo,
                place.thumbnail_url
            ]
        }
        return unique(previewURLs + placeURLs)
    }

    /// Returns the first `limit` candidates that have not failed to load.
    static func visibleURLs(candidates: [String], failed: Set<String>, limit: Int = 3) -> [String] {
        Array(candidates.lazy.filter { !failed.contains($0) }.prefix(limit))
    }

    /// Drops nil, blank, and repeated URLs while preserving order.
    private static func unique(_ urls: [String?]) -> [String] {
        var seen = Set<String>()
        return urls.compactMap { url in
            guard let url = url?.trimmingCharacters(in: .whitespaces),
                  !url.isEmpty,
                  URL(string: url) != nil,
                  seen.insert(url).inserted else { return nil }
            return url
        }
    }
}
