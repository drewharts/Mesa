//
//  ListCoverView.swift
//  loc
//
//  DUMB Component: The single cover for lists backed by place-photo URLs (Explore). Priority:
//  user-set image, else a collage of the list's place photos, else the letter-gradient placeholder.
//

import SwiftUI

/// Fills its frame with a list's cover: user image, else place-photo collage, else generated placeholder.
struct ListCoverView: View {
    let seed: String
    var name: String? = nil
    var emoji: String? = nil
    var imageURL: String? = nil
    var placePhotoURLs: [String] = []
    var cellSize: CGSize = CGSize(width: 320, height: 420)

    var body: some View {
        ZStack {
            ListCoverPlaceholder(seed: seed, name: name, emoji: emoji)
            if let url = userImageURL {
                CachedAsyncImage(url: url, targetSize: cellSize) { Color.clear }
                    .aspectRatio(contentMode: .fill)
            } else {
                PlacePhotoCollage(photoURLs: placePhotoURLs, cellSize: cellSize)
            }
        }
    }

    private var userImageURL: URL? {
        guard let imageURL, !imageURL.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return URL(string: imageURL)
    }
}
