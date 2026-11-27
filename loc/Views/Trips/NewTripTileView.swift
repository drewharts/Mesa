//
//  NewTripTileView.swift
//  loc
//
//  Square "+" tile at the top of the Trips list that starts new-trip creation.
//

import SwiftUI

/// Rounded square tile with a centered accent-orange plus; tapping it starts a new trip.
struct NewTripTileView: View {
    let onTap: () -> Void

    private let side: CGFloat = 96

    var body: some View {
        Button(action: onTap) {
            Image(systemName: "plus")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Color.mesaAccent)
                .frame(width: side, height: side)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel("New trip")
        .accessibilityIdentifier("trips.new")
    }
}
