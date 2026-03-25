//  PlaceSelectionPhotoHeader.swift
//  loc
//
//  DUMB Component: Displays photo thumbnail and place count header.
//  Single Responsibility: Render the photo context header for place selection.

import SwiftUI

struct PlaceSelectionPhotoHeader: View {
    let thumbnail: UIImage?
    let placeCount: Int
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 16) {
            thumbnailImage
            titleContent
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    private var thumbnailImage: some View {
        Group {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
        }
        .frame(width: 80, height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    private var titleContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Select a Place")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            if isLoading {
                Text("Searching nearby...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else if placeCount > 0 {
                Text("\(placeCount) places near photo")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("No places found nearby")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}
