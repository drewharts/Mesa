//
//  ListTilePhoto.swift
//  loc
//
//  Which stored photo a list tile shows, so tiles and the image prefetcher agree on the URL
//  (and therefore on the cache key).
//

import Foundation

enum ListTilePhoto {
    /// The place's own photo URL (latest review photo, then thumbnail); nil when it has none.
    static func url(for place: LightweightPlace) -> URL? {
        for candidate in [place.latest_review_photo, place.thumbnail_url] {
            if let candidate, !candidate.isEmpty, let url = URL(string: candidate) { return url }
        }
        return nil
    }
}
