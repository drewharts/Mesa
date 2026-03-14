//
//  CityAnnotationMarkerView.swift
//  loc
//
//  Minimal capsule map annotation showing city name and place count.
//

import SwiftUI

/// Capsule marker displayed on the map for city-level annotations.
struct CityAnnotationMarkerView: View {
    let city: CityAnnotation
    let isSelected: Bool

    var body: some View {
        Text(city.name)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
        )
        .shadow(color: .black.opacity(0.15), radius: isSelected ? 6 : 3, y: 2)
        .scaleEffect(isSelected ? 1.08 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}
