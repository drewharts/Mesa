//
//  ExploreFeaturedCard.swift
//  loc
//
//  DUMB Component: Large hero card for a featured list at the top of Explore: photo collage,
//  title, subtitle and an optional prominent "Find a table" button.
//

import SwiftUI

/// Featured list hero. Tapping the card opens the list; the button (when offered) opens it and starts a table search.
/// The card body and the button are siblings in a ZStack (never nested gestures), so neither can swallow the other's tap.
struct ExploreFeaturedCard: View {
    let config: FeaturedListConfig
    /// Place photo candidates for the collage (may be empty until loaded).
    let photoURLs: [String]
    /// True while this card's list is being resolved and opened; shows progress and ignores repeat taps.
    var isOpening: Bool = false
    let onOpen: () -> Void
    let onFindTable: () -> Void

    private let cornerRadius: CGFloat = 20

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            cardBody
            if config.offersFindTable {
                findTableButton
                    .padding(16)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
    }

    // MARK: - Subviews

    private var scrim: some View {
        LinearGradient(colors: [.black.opacity(0.0), .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
            .allowsHitTesting(false)
    }

    /// The tappable card: collage, scrim and copy. Its text never intercepts touches.
    private var cardBody: some View {
        Button(action: { if !isOpening { onOpen() } }) {
            Color.clear
                .frame(height: ExploreCoverMetrics.hero.height)
                .overlay { ListCoverView(seed: config.listId, name: config.title, placePhotoURLs: photoURLs, cellSize: ExploreCoverMetrics.hero) }
                .overlay { scrim }
                .overlay(alignment: .bottomLeading) { copy }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(config.title)
    }

    private var copy: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("FEATURED")
                .font(.caption2.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.85))
            Text(config.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(2)
            Text(config.subtitle)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(2)
            if config.offersFindTable {
                // Reserves the space the overlaid button occupies.
                Color.clear.frame(height: 44)
            }
        }
        .multilineTextAlignment(.leading)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .allowsHitTesting(false)
    }

    private var findTableButton: some View {
        Button(action: { if !isOpening { onFindTable() } }) {
            HStack(spacing: 8) {
                if isOpening {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "fork.knife")
                }
                Text("Find a table")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .frame(height: 44)
            .background(Capsule().fill(Color.mesaAccent))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the list and checks which places have tables")
    }
}
