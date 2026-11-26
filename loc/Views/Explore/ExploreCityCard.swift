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
    /// Candidate photos of top places in the city, best first; the first that loads is shown, and the
    /// generated gradient stays until one does (or when there are none).
    var photoURLs: [String] = []
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                ListCoverPlaceholder(seed: city.key, showsGlyph: false)
                if !photoURLs.isEmpty {
                    PlacePhotoCollage(photoURLs: photoURLs, cellSize: ExploreCoverMetrics.city, allowsGrid: false)
                }
                LinearGradient(colors: [.black.opacity(0.05), .black.opacity(photoURLs.isEmpty ? 0.45 : 0.7)], startPoint: .top, endPoint: .bottom)
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
