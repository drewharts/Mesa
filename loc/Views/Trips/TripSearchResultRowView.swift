//
//  TripSearchResultRowView.swift
//  loc
//
//  Single search result row for adding a place to a trip.
//

import SwiftUI

/// Search result row with tappable text area for navigation and separate add/remove action icon.
struct TripSearchResultRowView: View {
    let suggestion: MesaPlaceSuggestion
    let isAdding: Bool
    let isInTrip: Bool
    let isResolving: Bool
    let onNavigate: () -> Void
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
        HStack {
            Button(action: onNavigate) {
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
            }
            .disabled(isResolving)

            Spacer()

            if isResolving {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Button(action: isInTrip ? onRemove : onAdd) {
                    actionIcon
                }
                .disabled(isAdding)
            }
        }
    }
}
