//
//  MapCircleButton.swift
//  loc
//
//  DUMB Components: translucent circular controls floating over the map.
//  The label is separate so the same look can be used inside a Menu.
//

import SwiftUI

/// Circular material icon used by floating map controls (single source of truth for their styling).
struct MapCircleButtonLabel: View {
    let systemName: String
    var tint: Color = .secondary
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(.ultraThinMaterial)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
            .shadow(radius: 4)
    }
}

/// Tappable circular map control.
struct MapCircleButton: View {
    let systemName: String
    var tint: Color = .secondary
    var size: CGFloat = 44
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            MapCircleButtonLabel(systemName: systemName, tint: tint, size: size)
        }
        .accessibilityLabel(accessibilityLabel)
    }
}
