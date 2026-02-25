//
//  TripSearchResultRowView.swift
//  loc
//
//  Single search result row for adding a place to a trip.
//

import SwiftUI

/// Search result row displaying place name, address, and an add/checkmark action icon.
struct TripSearchResultRowView: View {
    let suggestion: MesaPlaceSuggestion
    let isAdding: Bool
    let isInTrip: Bool
    let onAdd: () -> Void
    let onRemove: () -> Void

    /// Action icon: spinner while adding, checkmark if in trip, plus otherwise.
    private var actionIcon: some View {
        Group {
            if isAdding {
                ProgressView()
                    .scaleEffect(0.8)
            } else if isInTrip {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
            } else {
                Image(systemName: "plus.circle")
                    .foregroundStyle(.blue)
                    .font(.title3)
            }
        }
    }

    var body: some View {
        Button(action: onAdd) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.name)
                        .font(.body)
                        .foregroundStyle(.primary)

                    if let address = suggestion.address {
                        Text(address)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                actionIcon
            }
        }
        .disabled(isAdding)
    }
}
