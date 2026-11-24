//
//  ExploreFeaturedCard.swift
//  loc
//
//  DUMB Component: Large hero card for a featured list at the top of Explore: photo collage,
//  title, subtitle and an optional prominent "Find a table" button.
//

import SwiftUI

/// Featured list hero. Tapping the card opens the list; the button (when offered) opens it and starts a table search.
struct ExploreFeaturedCard: View {
    let config: FeaturedListConfig
    /// Place photo candidates for the collage (may be empty until loaded).
    let photoURLs: [String]
    let onOpen: () -> Void
    let onFindTable: () -> Void

    private let cornerRadius: CGFloat = 20

    var body: some View {
        Color.clear
            .frame(height: ExploreCoverMetrics.hero.height)
            .overlay { ListCoverView(seed: config.listId, name: config.title, placePhotoURLs: photoURLs, cellSize: ExploreCoverMetrics.hero) }
            .overlay { scrim }
            .overlay(alignment: .bottomLeading) { content }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .onTapGesture(perform: onOpen)
            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(config.title)
    }

    // MARK: - Subviews

    private var scrim: some View {
        LinearGradient(colors: [.black.opacity(0.0), .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
    }

    private var content: some View {
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
                findTableButton
            }
        }
        .multilineTextAlignment(.leading)
        .padding(16)
    }

    private var findTableButton: some View {
        Button(action: onFindTable) {
            Label("Find a table", systemImage: "fork.knife")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.mesaAccent))
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
        .accessibilityHint("Opens the list and checks which places have tables")
    }
}
