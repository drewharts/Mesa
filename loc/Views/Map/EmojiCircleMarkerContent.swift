//
//  EmojiCircleMarkerContent.swift
//  loc
//
//  Google-style emoji-in-circle marker content, extracted from the former
//  CustomPlaceAnnotationView fallback branch so it can be rendered into a
//  static image by MapMarkerImageFactory without needing a full PlaceAnnotation.
//

import SwiftUI

/// Renders a place-type emoji inside a white circle, used as a fallback marker
/// when no profile-photo composite image is available for a place.
struct EmojiCircleMarkerContent: View {
    let placeType: String
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: isSelected ? 46 : 38, height: isSelected ? 46 : 38)
                .shadow(
                    color: Color.black.opacity(0.25),
                    radius: isSelected ? 6 : 4,
                    x: 0,
                    y: 2
                )

            Text(PlaceTypeEmoji.emoji(for: placeType))
                .font(.system(size: isSelected ? 24 : 19))
        }
    }
}
