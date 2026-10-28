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

    private var storedPhotoURL: URL? {
        let candidate = (place.photoUrls ?? []).first { url in
            !url.isEmpty && !url.contains("googleapis.com")
        }
        return candidate.flatMap(URL.init(string:))
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
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .animation(.easeOut(duration: 0.2), value: image != nil || sharedImage != nil)
        .task(id: placeKey) { await load() }
    }

    private func load() async {
        if image != nil || sharedImage != nil { return }
        let pixel = size * UIScreen.main.scale
        if let url = storedPhotoURL,
           let img = await ImageCacheService.shared.fetchImage(for: url, targetSize: CGSize(width: pixel, height: pixel)) {
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
