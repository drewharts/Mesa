//
//  TripSelectablePlaceCardPhoto.swift
//  loc
//
//  Photo content for the selectable place card tile
//

import SwiftUI

/// Displays the best available photo for a place card at the given size.
struct TripSelectablePlaceCardPhoto: View {
    let place: LightweightPlace
    let size: CGSize

    var body: some View {
        if let contentUrl = place.content_url,
           let thumbnailURL = ExternalMetadataCache.shared.getCachedThumbnailUrl(for: contentUrl) {
            CachedAsyncImage(url: URL(string: thumbnailURL), targetSize: size) {
                ShimmerView()
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: size.width, height: size.height)
            .clipped()
        } else if let photoUrl = place.latest_review_photo, let url = URL(string: photoUrl) {
            CachedAsyncImage(url: url, targetSize: size) {
                ShimmerView()
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: size.width, height: size.height)
            .clipped()
        } else if let contentUrl = place.content_url {
            Color.clear
                .onAppear {
                    Task {
                        _ = await ExternalMetadataCache.shared.getMetadata(for: contentUrl)
                    }
                }
        }
    }
}
