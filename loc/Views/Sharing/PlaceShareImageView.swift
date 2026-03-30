//
//  PlaceShareImageView.swift
//  loc
//
//  DUMB Component: Rendered to a UIImage for sharing a place via Messages.
//  Shows the place photo with name and location overlaid at the bottom.
//

import SwiftUI

/// Card view rendered to an image for place sharing via Messages and other apps.
struct PlaceShareImageView: View {
    let placeName: String
    let subtitle: String
    let backgroundImage: UIImage?

    private let cardWidth: CGFloat = 600
    private let cardHeight: CGFloat = 400

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            background
            gradientOverlay
            textOverlay
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Background

    @ViewBuilder
    private var background: some View {
        if let image = backgroundImage {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: cardWidth, height: cardHeight)
                .clipped()
        } else {
            LinearGradient(
                colors: [
                    Color(red: 0.8, green: 0.4, blue: 0.1),
                    Color(red: 0.6, green: 0.25, blue: 0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var gradientOverlay: some View {
        LinearGradient(
            colors: [.clear, .clear, .black.opacity(0.7)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Text Overlay

    private var textOverlay: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(placeName)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(2)

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)
            }
        }
        .padding(24)
    }
}
