//
//  ExploreCityCard.swift
//  loc
//
//  DUMB Component: City tile with name and list count for "Browse by city".
//

import SwiftUI

/// Tappable city tile: place photo under a dark overlay, on a generated gradient fallback.
struct ExploreCityCard: View {
    let city: ExploreCity
    /// Photo of a top place in the city; the generated gradient shows until it loads (or without one).
    var photoURL: String? = nil
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                ListCoverPlaceholder(seed: city.key, showsGlyph: false)
                if let photoURL {
                    PlacePhotoCollage(photoURLs: [photoURL], cellSize: CGSize(width: 300, height: 192))
                }
                LinearGradient(colors: [.black.opacity(0.05), .black.opacity(photoURL == nil ? 0.45 : 0.7)], startPoint: .top, endPoint: .bottom)
                label
            }
            .frame(width: 150, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Subviews

    private var label: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(city.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Text(city.listCountLabel)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(10)
    }
}
