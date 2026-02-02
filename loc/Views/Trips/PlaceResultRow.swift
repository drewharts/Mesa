//
//  PlaceResultRow.swift
//  loc
//
//  Individual place result row for search results.
//

import SwiftUI

/// Displays a single place result in the search overlay.
struct PlaceResultRow: View {
    let place: LightweightPlace
    let onSelect: (LightweightPlace) -> Void

    var body: some View {
        Button(action: { onSelect(place) }) {
            HStack(spacing: 12) {
                placeIcon
                placeInfo
                Spacer()
                addIcon
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color.white)
        }
        .buttonStyle(.plain)
    }

    /// Map pin icon for the place.
    private var placeIcon: some View {
        Image(systemName: "mappin.circle.fill")
            .font(.title2)
            .foregroundColor(.red)
    }

    /// Place name and address information.
    private var placeInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(place.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.black)
                .lineLimit(1)

            if let address = place.address, !address.isEmpty {
                Text(address)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
        }
    }

    /// Add icon indicating the row is tappable.
    private var addIcon: some View {
        Image(systemName: "plus.circle")
            .foregroundColor(.blue)
    }
}
