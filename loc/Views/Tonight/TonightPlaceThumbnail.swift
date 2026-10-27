//
//  TonightPlaceThumbnail.swift
//  loc
//
//  DUMB: square place photo over a colored placeholder (never blank white).
//  Only uses stored, non-Google photo URLs so it never triggers Places Photo billing.
//

import SwiftUI

struct TonightPlaceThumbnail: View {
    let place: DetailPlace
    var size: CGFloat = 64

    private var placeholderColor: Color {
        let hue = Double(abs(place.name.hashValue) % 360) / 360.0
        return Color(hue: hue, saturation: 0.55, brightness: 0.85)
    }

    private var photoURL: URL? {
        let candidate = (place.photoUrls ?? []).first { url in
            !url.isEmpty && !url.contains("googleapis.com") && !url.contains("maps.googleapis")
        }
        return candidate.flatMap(URL.init(string:))
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(placeholderColor)
            .overlay(
                Text(PlaceTypeEmoji.emoji(for: place.categories?.first ?? "Place"))
                    .font(.system(size: size * 0.4))
            )
            .overlay {
                if let photoURL {
                    AsyncImage(url: photoURL) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            Color.clear
                        }
                    }
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
