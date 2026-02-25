//
//  TripPlaceActionBadge.swift
//  loc
//
//  Overlay badge for adding/removing a place from a trip, shown on top of place cards.
//

import SwiftUI

/// Add/checkmark/spinner badge overlaid on place cards in the trip add-place flow.
struct TripPlaceActionBadge: View {
    let isInTrip: Bool
    let isAdding: Bool
    let onAdd: () -> Void
    let onRemove: () -> Void

    var body: some View {
        Group {
            if isAdding {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(0.8)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(.ultraThinMaterial))
            } else if isInTrip {
                Button(action: onRemove) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(.ultraThinMaterial))
                }
                .buttonStyle(.plain)
            } else {
                Button(action: onAdd) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(.ultraThinMaterial))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
    }
}
