//
//  ExploreListCard.swift
//  loc
//
//  DUMB Component: Cover, name, and place count for a public list on the Explore tab.
//

import SwiftUI

/// Tappable list card with a cover image (or generated placeholder) and caption.
struct ExploreListCard: View {
    let list: ExploreList
    /// Place photos used when the list has no cover image of its own.
    var placePhotoURLs: [String] = []
    let onTap: () -> Void

    private let coverCornerRadius: CGFloat = 10

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                cover
                info
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Subviews

    private var cover: some View {
        Color.clear
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .overlay {
                ListCoverView(seed: list.id, name: list.name, imageURL: list.imageURL, placePhotoURLs: placePhotoURLs)
            }
            .clipShape(RoundedRectangle(cornerRadius: coverCornerRadius))
            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(list.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    // MARK: - Derived Values


    private var caption: String {
        guard let owner = list.ownerName, !owner.isEmpty else { return list.placeCountLabel }
        return "\(list.placeCountLabel) · \(owner)"
    }
}
