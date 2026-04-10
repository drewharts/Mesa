//
//  CityListTile.swift
//  loc
//
//  Tile view for a list in the city detail horizontal scroll row.
//

import SwiftUI

/// Square tile displaying a list with photo collage background and overlaid name.
struct CityListTile: View {
    let list: CityDetailListRecord
    let places: [LightweightPlace]
    @Binding var placeColors: [UUID: Color]
    let onTap: () -> Void
    var onCreatorTap: ((String) -> Void)? = nil

    var body: some View {
        Button {
            onTap()
        } label: {
            ZStack(alignment: .bottomLeading) {
                ListPhotoCollage(places: places, placeColors: $placeColors)

                gradientOverlay

                HStack(alignment: .bottom, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(list.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .lineLimit(2)

                        Text("\(list.place_count) place\(list.place_count == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    Spacer()

                    creatorAvatar
                }
                .padding(10)
            }
            .aspectRatio(1, contentMode: .fill)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .onAppear { prefetchThumbnails() }
    }

    // MARK: - Creator Avatar

    /// Small circular profile photo of the list creator, tappable to view their profile.
    @ViewBuilder
    private var creatorAvatar: some View {
        if let photoUrl = list.creator_photo_url, let url = URL(string: photoUrl) {
            Button {
                onCreatorTap?(list.user_id)
            } label: {
                CachedAsyncImage(url: url, targetSize: CGSize(width: 24, height: 24)) {
                    creatorInitialsCircle
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 24, height: 24)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 1))
            }
            .buttonStyle(.plain)
        } else if list.creator_name != nil {
            Button {
                onCreatorTap?(list.user_id)
            } label: {
                creatorInitialsCircle
            }
            .buttonStyle(.plain)
        }
    }

    /// Fallback circle with creator's initial.
    private var creatorInitialsCircle: some View {
        Circle()
            .fill(Color.white.opacity(0.3))
            .frame(width: 24, height: 24)
            .overlay(
                Text(String(list.creator_name?.prefix(1) ?? "").uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
            )
    }

    /// Prefetches external video thumbnails for places with content URLs.
    private func prefetchThumbnails() {
        for place in places {
            if let contentUrl = place.content_url {
                Task { _ = await ExternalMetadataCache.shared.getMetadata(for: contentUrl) }
            }
        }
    }

    /// Gradient overlay for text readability on photo collage.
    private var gradientOverlay: some View {
        LinearGradient(
            colors: [.clear, .black.opacity(0.6)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
