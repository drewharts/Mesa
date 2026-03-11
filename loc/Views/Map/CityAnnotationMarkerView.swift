//
//  CityAnnotationMarkerView.swift
//  loc
//
//  Pill-shaped map annotation for city-level markers.
//  Shows emoji stack, city name, and summary counts.
//

import SwiftUI

/// Pill-shaped marker displayed on the map for city-level annotations.
struct CityAnnotationMarkerView: View {
    let city: CityAnnotation
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 2) {
            emojiRow
            cityLabel
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
        )
        .shadow(color: .black.opacity(0.15), radius: isSelected ? 6 : 3, y: 2)
        .scaleEffect(isSelected ? 1.08 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    /// Emoji row showing top place type emojis.
    private var emojiRow: some View {
        HStack(spacing: 2) {
            ForEach(city.topEmojis, id: \.self) { emoji in
                Text(emoji)
                    .font(.system(size: 14))
            }
        }
    }

    /// City name and summary label.
    private var cityLabel: some View {
        VStack(spacing: 1) {
            Text(city.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(city.summary)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
