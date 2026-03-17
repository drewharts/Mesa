//
//  TripSelectionRowView.swift
//  loc
//
//  Single trip row in the save-to-trip selection sheet
//

import SwiftUI

/// Displays a trip row with name, date range, and membership indicator.
struct TripSelectionRowView: View {
    let trip: LightweightTrip
    let isInTrip: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                tripInfo

                Spacer()

                selectionIndicator
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Trip Info

    private var tripInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(trip.name)
                .font(.body)
                .foregroundStyle(.primary)

            HStack(spacing: 4) {
                Text(trip.dateRangeString)
                Text("·")
                    .foregroundStyle(.secondary.opacity(0.5))
                Text("\(trip.placeCount) places")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Selection Indicator

    private var selectionIndicator: some View {
        ZStack {
            if isInTrip {
                Circle()
                    .fill(Color.primary)
                    .frame(width: 20, height: 20)
            } else {
                Circle()
                    .stroke(Color.primary, lineWidth: 1.5)
                    .frame(width: 20, height: 20)
            }
        }
    }
}
