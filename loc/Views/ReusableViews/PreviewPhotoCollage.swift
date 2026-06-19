//
//  PreviewPhotoCollage.swift
//  loc
//
//  DUMB Component: Shows up to 3 preview photos in a collage layout.
//  Uses photo URLs embedded in list metadata — no per-list place fetch needed.
//

import SwiftUI

/// Photo collage using pre-fetched preview URLs from list metadata.
struct PreviewPhotoCollage: View {
    let photoURLs: [String]

    var body: some View {
        switch photoURLs.count {
        case 0:
            Color(.systemGray6)
        case 1:
            CollageCell(urlString: photoURLs[0])
        case 2:
            HStack(spacing: 1.5) {
                CollageCell(urlString: photoURLs[0])
                CollageCell(urlString: photoURLs[1])
            }
        default:
            HStack(spacing: 1.5) {
                VStack(spacing: 1.5) {
                    CollageCell(urlString: photoURLs[0])
                    CollageCell(urlString: photoURLs[1])
                }
                CollageCell(urlString: photoURLs[2])
            }
        }
    }
}

/// Single cell in a preview photo collage — fills and clips within layout bounds.
private struct CollageCell: View {
    let urlString: String

    var body: some View {
        Color(.systemGray6)
            .overlay(
                CachedAsyncImage(url: URL(string: urlString), targetSize: nil) {
                    Color(.systemGray6)
                }
                .scaledToFill()
            )
            .clipped()
            .contentShape(Rectangle())
    }
}
