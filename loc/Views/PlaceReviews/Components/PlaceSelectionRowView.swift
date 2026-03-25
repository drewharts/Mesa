//  PlaceSelectionRowView.swift
//  loc
//
//  DUMB Component: Card displaying a nearby place option for selection.
//  Single Responsibility: Render a single place row in the selection list.

import SwiftUI

struct PlaceSelectionRowView: View {
    let place: NearbyPlaceFeature
    let formattedDistance: String
    let typeEmoji: String
    let onSelect: () -> Void
    let isLoading: Bool

    private let cardBackground = Color(red: 248/255, green: 248/255, blue: 250/255)

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                emojiTile
                placeInfo
                Spacer()
                trailingIndicator
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }

    private var emojiTile: some View {
        Text(typeEmoji)
            .font(.system(size: 24))
            .frame(width: 48, height: 48)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var placeInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(place.properties.name)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(1)

            Text(place.properties.address.isEmpty ? "Address not available" : place.properties.address)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)

            metadataRow
        }
    }

    private var metadataRow: some View {
        HStack(spacing: 8) {
            if let rating = place.properties.rating {
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.orange)
                    Text(String(format: "%.1f", rating))
                }
                .font(.caption)
                .foregroundColor(.secondary)

                Text("·")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 2) {
                Image(systemName: "mappin")
                Text(formattedDistance)
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }

    private var trailingIndicator: some View {
        Group {
            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
