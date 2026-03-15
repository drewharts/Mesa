//
//  TripMapPlaceRowView.swift
//  loc
//
//  Place row in the trip map itinerary sheet
//

import SwiftUI

/// A row displaying a trip place with a colored number badge matching the map pin.
struct TripMapPlaceRowView: View {
    let annotation: TripMapAnnotation
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                numberBadge
                placeInfo
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? Color(.systemGray5) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Colored number badge matching the map pin color.
    private var numberBadge: some View {
        Text("\(annotation.stopNumber)")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(Circle().fill(annotation.color))
    }

    /// Place name and type (or address fallback).
    private var placeInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(annotation.placeName)
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(1)

            let displayType = PlaceTypeTranslator.translate(annotation.placeType)
            if displayType != "Place" || annotation.placeAddress != nil {
                Text(displayType != "Place" ? displayType : (annotation.placeAddress ?? ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
