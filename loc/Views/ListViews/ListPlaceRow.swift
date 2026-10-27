//
//  ListPlaceRow.swift
//  loc
//
//  Place row for the map-first list sheet. Matches the profile tile design system:
//  10pt continuous corners, hairline gray stroke, soft shadow, subheadline-semibold name,
//  caption secondary text, deterministic colored placeholders instead of blank tiles, and a
//  category + neighborhood line. DUMB component: all behavior arrives through closures.
//

import SwiftUI

// MARK: - Row

struct ListPlaceRow: View {
    let place: LightweightPlace
    /// Neighborhood (or city) for the category line; nil while unknown.
    let locationText: String?
    let isSelected: Bool
    let showAddedBy: Bool
    /// Row tapped: highlight and center the pin.
    let onTap: () -> Void
    /// "Details" tapped on the selected row: open the place page.
    let onOpenDetail: () -> Void

    static let thumbnailSize: CGFloat = 72
    private let rowRadius: CGFloat = 14

    var body: some View {
        HStack(spacing: 12) {
            ListPlaceThumbnail(place: place, size: Self.thumbnailSize)

            VStack(alignment: .leading, spacing: 3) {
                Text(place.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                if let subtitle = Self.subtitle(for: place, locationText: locationText) {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                if showAddedBy, let addedBy = place.added_by_name, !addedBy.isEmpty {
                    Text("Added by \(addedBy)")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.8))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if isSelected {
                Button(action: onOpenDetail) {
                    HStack(spacing: 3) {
                        Text("Details")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.mesaAccent))
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: rowRadius, style: .continuous)
                .fill(isSelected ? Color.mesaAccent.opacity(0.10) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: rowRadius, style: .continuous)
                .stroke(isSelected ? Color.mesaAccent : Color.clear, lineWidth: 1.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: rowRadius, style: .continuous))
        .onTapGesture(perform: onTap)
        .animation(.easeOut(duration: 0.18), value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? AccessibilityTraits([.isButton, .isSelected]) : AccessibilityTraits.isButton)
    }

    // MARK: - Category Line

    /// "🍕 Pizza Restaurant · West Village", dropping whichever parts are unknown.
    static func subtitle(for place: LightweightPlace, locationText: String?) -> String? {
        var parts: [String] = []
        if let category = categoryLabel(for: place) {
            parts.append(category)
        }
        if let locationText, !locationText.isEmpty {
            parts.append(locationText)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private static func categoryLabel(for place: LightweightPlace) -> String? {
        guard let type = place.place_type?.trimmingCharacters(in: .whitespacesAndNewlines), !type.isEmpty else {
            return nil
        }
        let name = type.replacingOccurrences(of: "_", with: " ").capitalized
        return "\(PlaceTypeEmoji.emoji(for: type)) \(name)"
    }
}

// MARK: - Thumbnail

/// Square thumbnail: external video thumbnail, then review photo, then Google photo.
/// Shows a shimmer while loading and a deterministic colored placeholder when there is no image.
struct ListPlaceThumbnail: View {
    let place: LightweightPlace
    let size: CGFloat

    @ObservedObject private var externalMetadataCache = ExternalMetadataCache.shared
    @State private var failedUrls = Set<String>()

    private var imageURL: URL? {
        if let contentUrl = place.content_url,
           let cached = externalMetadataCache.getCachedThumbnailUrl(for: contentUrl),
           !failedUrls.contains(cached),
           let url = URL(string: cached) {
            return url
        }
        let candidates: [String?] = [place.latest_review_photo, place.thumbnail_url]
        for candidate in candidates {
            if let candidate, !candidate.isEmpty, !failedUrls.contains(candidate), let url = URL(string: candidate) {
                return url
            }
        }
        return nil
    }

    var body: some View {
        Group {
            if let url = imageURL {
                CachedAsyncImage(
                    url: url,
                    targetSize: CGSize(width: size, height: size),
                    placeholder: { ShimmerView() },
                    onFailure: { failedUrls.insert(url.absoluteString) }
                )
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipped()
            } else {
                ListCoverPlaceholder(
                    seed: place.place_id,
                    name: place.name,
                    emoji: place.place_type.map { PlaceTypeEmoji.emoji(for: $0) }
                )
                .frame(width: size, height: size)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
        .onAppear {
            // Kick off the external thumbnail fetch so it replaces the placeholder when ready.
            if let contentUrl = place.content_url,
               externalMetadataCache.getCachedThumbnailUrl(for: contentUrl) == nil {
                Task { _ = await ExternalMetadataCache.shared.getMetadata(for: contentUrl) }
            }
        }
    }
}

// MARK: - Skeleton

/// Shimmer skeleton shaped exactly like `ListPlaceRow` (same thumbnail, padding and line heights).
struct ListPlaceRowSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            SkeletonBlock(width: ListPlaceRow.thumbnailSize, height: ListPlaceRow.thumbnailSize, cornerRadius: 10)

            VStack(alignment: .leading, spacing: 8) {
                SkeletonBlock(width: 150, height: 14, cornerRadius: 6)
                SkeletonBlock(width: 110, height: 11, cornerRadius: 5)
            }

            Spacer(minLength: 8)
        }
        .padding(8)
        .accessibilityHidden(true)
    }
}
