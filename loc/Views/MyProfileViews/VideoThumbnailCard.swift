//
//  VideoThumbnailCard.swift
//  loc
//
//  Dumb view: Displays a video thumbnail with author info for selection grids.

import SwiftUI

struct VideoThumbnailCard: View {
    let video: ExternalVideo

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CustomImageLoader(
                urlString: video.thumbnailURL,
                contentMode: .fill,
                frameSize: CGSize(width: 160, height: 200),
                cornerRadius: 10,
                onFailure: {}
            )

            Text("@\(video.author.username)")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}
