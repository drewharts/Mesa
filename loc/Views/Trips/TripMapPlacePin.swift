//
//  TripMapPlacePin.swift
//  loc
//
//  Custom map annotation pin for the trip map place picker
//

import SwiftUI

/// Map annotation pin showing whether a place is already in the trip.
struct TripMapPlacePin: View {
    let placeName: String
    let isAlreadyAdded: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Image(systemName: isAlreadyAdded ? "checkmark.circle.fill" : "mappin.circle.fill")
                    .font(.title2)
                    .foregroundColor(isAlreadyAdded ? .green : .accentColor)
                    .background(
                        Circle()
                            .fill(.white)
                            .frame(width: 20, height: 20)
                    )

                Text(placeName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .buttonStyle(.plain)
    }
}
