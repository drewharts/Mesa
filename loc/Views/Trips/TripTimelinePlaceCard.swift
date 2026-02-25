//
//  TripTimelinePlaceCard.swift
//  loc
//
//  Timeline-style card for a place in the day itinerary
//

import SwiftUI

/// Displays a place as a timeline card with numbered stop, connector lines, and place details.
struct TripTimelinePlaceCard: View {
    let place: TripDayPlace
    let number: Int
    let isFirst: Bool
    let isLast: Bool

    private let mesaCharcoal = Color(red: 45/255, green: 45/255, blue: 45/255)
    private let connectorWidth: CGFloat = 2
    private let timelineColumnWidth: CGFloat = 40
    private let circleSize: CGFloat = 28
    private let photoSize: CGFloat = 80

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            timelineColumn
            placeCard
        }
    }

    // MARK: - Timeline Column

    private var timelineColumn: some View {
        VStack(spacing: 0) {
            topConnector
            numberCircle
            bottomConnector
        }
        .frame(width: timelineColumnWidth)
    }

    /// Top connector line, hidden for the first stop.
    private var topConnector: some View {
        Rectangle()
            .fill(mesaCharcoal.opacity(0.3))
            .frame(width: connectorWidth, height: 16)
            .opacity(isFirst ? 0 : 1)
    }

    /// Numbered circle badge for this stop.
    private var numberCircle: some View {
        Text("\(number)")
            .font(.caption)
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .frame(width: circleSize, height: circleSize)
            .background(mesaCharcoal)
            .clipShape(Circle())
    }

    /// Bottom connector line, hidden for the last stop.
    private var bottomConnector: some View {
        Rectangle()
            .fill(mesaCharcoal.opacity(0.3))
            .frame(width: connectorWidth)
            .frame(maxHeight: .infinity)
            .opacity(isLast ? 0 : 1)
    }

    // MARK: - Place Card

    private var placeCard: some View {
        HStack(spacing: 12) {
            placePhoto
            placeInfo
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
    }

    /// Place photo thumbnail or hash-based fallback color.
    @ViewBuilder
    private var placePhoto: some View {
        if let photoUrl = place.placePhoto, let url = URL(string: photoUrl) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(fallbackColor)
            }
            .frame(width: photoSize, height: photoSize)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(fallbackColor)
                .frame(width: photoSize, height: photoSize)
                .overlay {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.8))
                }
        }
    }

    /// Place name, address, added-by, and inline note.
    private var placeInfo: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(place.placeName ?? "Unknown Place")
                .font(.headline)
                .lineLimit(1)

            if let address = place.placeAddress {
                Text(address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let addedBy = place.addedByName {
                Text("Added by \(addedBy)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if let note = place.note, !note.isEmpty {
                Label(note, systemImage: "note.text")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
                    .lineLimit(2)
            }
        }
    }

    // MARK: - Helpers

    /// Hash-based hue fallback color when no photo is available.
    private var fallbackColor: Color {
        let hash = place.placeId.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.8)
    }
}
