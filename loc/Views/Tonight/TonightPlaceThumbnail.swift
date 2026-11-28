//
//  TonightPlaceThumbnail.swift
//  loc
//
//  Square place photo for the Tonight / group pick cards.
//  Photo source order (same pipeline as the list tiles, no Google Places Photo billing):
//    1. the place's own stored, non-Google photo URL (disk + memory cached via ImageCacheService)
//    2. DetailPlaceViewModel.fetchPlaceImage: review/post photos, then TikTok video thumbnail
//  Placeholder is a soft neutral tile with a small glyph — never blank, never a giant emoji.
//

import SwiftUI

struct TonightPlaceThumbnail: View {
    let place: DetailPlace
    var size: CGFloat = 64

    @EnvironmentObject private var detailPlaceViewModel: DetailPlaceViewModel
    @State private var image: UIImage?

    private var placeKey: String { place.id.uuidString }

    private var storedPhotoURL: URL? { Self.storedPhotoURL(for: place) }

    /// Returns the place's first stored (non-Google) photo; Google links are tried later by the shared pipeline.
    static func storedPhotoURL(for place: DetailPlace) -> URL? {
        let candidate = DetailPlaceViewModel.rankedPhotoURLs(place.photoUrls ?? []).first { url in
            !url.contains("googleapis.com") && !url.contains("googleusercontent.com")
        }
        return candidate.flatMap(URL.init(string:))
    }

    /// Pixel size the thumbnail requests its stored photo at, so a warm-up hits the same cache entry.
    static func requestSize(_ size: CGFloat) -> CGSize {
        let pixel = size * UIScreen.main.scale
        return CGSize(width: pixel, height: pixel)
    }

    /// Image already loaded by the shared pipeline (empty UIImage = "none available").
    private var sharedImage: UIImage? {
        guard let img = detailPlaceViewModel.placeImages[placeKey], img.size.width > 0 else { return nil }
        return img
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.tertiarySystemFill), Color(.secondarySystemFill)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Image(systemName: "fork.knife")
                .font(.system(size: size * 0.28, weight: .medium))
                .foregroundColor(.secondary.opacity(0.5))
            if let shown = image ?? sharedImage {
                Image(uiImage: shown)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            }
        }
        .frame(width: size, height: size)
        .screenshotTileEmpty(image == nil && sharedImage == nil)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .animation(.easeOut(duration: 0.2), value: image != nil || sharedImage != nil)
        .task(id: placeKey) { await load() }
    }

    private func load() async {
        if image != nil || sharedImage != nil { return }
        if let url = storedPhotoURL,
           let img = await ImageCacheService.shared.fetchImage(for: url, targetSize: Self.requestSize(size)) {
            image = img
            return
        }
        // Fall back to the app's shared tile pipeline (review photos, then video thumbnail).
        if detailPlaceViewModel.places[placeKey] == nil {
            detailPlaceViewModel.places[placeKey] = place
        }
        detailPlaceViewModel.fetchPlaceImage(for: placeKey)
    }
}
