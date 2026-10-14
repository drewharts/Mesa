//
//  ListCoverCollage.swift
//  loc
//
//  Shared list cover: shows up to 3 images in a collage, falling back to the next candidate image
//  (another photo of the same place, or another place in the list) whenever one fails to load.
//  Candidate order lives in ListCoverImageResolver; failed URLs are shared app-wide via ImageLoadFailureRegistry.
//

import SwiftUI

struct ListCoverCollage: View {
    let previewPhotos: [String]?
    let places: [LightweightPlace]
    @Binding var placeColors: [UUID: Color]

    @ObservedObject private var failures = ImageLoadFailureRegistry.shared
    @ObservedObject private var metadataCache = ExternalMetadataCache.shared

    private var visibleURLs: [String] {
        let candidates = ListCoverImageResolver.candidateURLs(
            previewPhotos: previewPhotos,
            places: places,
            videoThumbnail: { metadataCache.getCachedThumbnailUrl(for: $0) }
        )
        return ListCoverImageResolver.visibleURLs(candidates: candidates, failed: failures.failedURLs)
    }

    var body: some View {
        let urls = visibleURLs
        switch urls.count {
        case 0:
            // Every image failed (or none exist): keep the colored place tiles.
            ListPhotoCollage(places: Array(places.prefix(3)), placeColors: $placeColors)
        case 1:
            ListCoverCollageCell(urlString: urls[0])
        case 2:
            HStack(spacing: 1.5) {
                ListCoverCollageCell(urlString: urls[0])
                ListCoverCollageCell(urlString: urls[1])
            }
        default:
            HStack(spacing: 1.5) {
                VStack(spacing: 1.5) {
                    ListCoverCollageCell(urlString: urls[0])
                    ListCoverCollageCell(urlString: urls[1])
                }
                ListCoverCollageCell(urlString: urls[2])
            }
        }
    }
}
