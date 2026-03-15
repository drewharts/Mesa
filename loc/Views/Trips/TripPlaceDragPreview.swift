//
//  TripPlaceDragPreview.swift
//  loc
//
//  Lightweight drag preview for cross-day place drag
//

import SwiftUI

/// Capsule preview shown while dragging a place row between days.
struct TripPlaceDragPreview: View {
    let placeName: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "mappin.circle.fill")
                .foregroundColor(.accentColor)
            Text(placeName)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
}
