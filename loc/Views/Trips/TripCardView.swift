//
//  TripCardView.swift
//  loc
//
//  Card view for displaying a trip in the trips list
//

import SwiftUI

/// Displays a trip summary card with name, dates, place count, and collaborator avatars.
struct TripCardView: View {
    let trip: LightweightTrip

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(trip.dateRangeString)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                collaboratorAvatars
            }

            HStack(spacing: 16) {
                Label("\(trip.placeCount) places", systemImage: "mappin")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Label("\(trip.numberOfDays) days", systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let isShared = trip.isShared, isShared {
                    Label("Shared", systemImage: "person.2")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Collaborator Avatars

    private var collaboratorAvatars: some View {
        HStack(spacing: -8) {
            if let photos = trip.collaboratorPhotos {
                ForEach(photos.prefix(3), id: \.self) { urlString in
                    AsyncImage(url: URL(string: urlString)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                }
            }
        }
    }
}
