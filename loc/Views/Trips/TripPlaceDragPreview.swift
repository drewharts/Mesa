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

    private let mesaCharcoal = Color(red: 45/255, green: 45/255, blue: 45/255)

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "mappin.circle.fill")
                .foregroundColor(mesaCharcoal)
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
