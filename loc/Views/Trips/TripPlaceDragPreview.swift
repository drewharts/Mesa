//
//  TripPlaceDragPreview.swift
//  loc
//
//  Lightweight drag preview for cross-day place drag
//

import SwiftUI

/// Compact rounded preview shown while dragging a place row between days.
struct TripPlaceDragPreview: View {
    private let mesaCharcoal = Color(red: 45/255, green: 45/255, blue: 45/255)

    var body: some View {
        Image(systemName: "mappin.circle.fill")
            .font(.title2)
            .foregroundStyle(.white)
            .frame(width: 40, height: 40)
            .background(mesaCharcoal)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
    }
}
