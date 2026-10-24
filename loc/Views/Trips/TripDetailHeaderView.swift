//
//  TripDetailHeaderView.swift
//  loc
//
//  Dumb view displaying trip name, date range, collaborator avatars, and summary info
//

import SwiftUI

/// Displays trip header info: name, date range, stop/day counts, and collaborator avatars.
struct TripDetailHeaderView: View {
    let trip: Trip
    let collaborators: [LightweightCollaborator]
    var stopCount: Int = 0

    private let maxAvatarsShown = 4
    private let avatarSize: CGFloat = 30
    private let avatarOverlap: CGFloat = -8

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(trip.name)
                .font(.title2)
                .fontWeight(.bold)
                .lineLimit(2)

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Label(formattedDateRange, systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(summaryText)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                if !collaborators.isEmpty {
                    collaboratorAvatars
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summaryText: String {
        let days = "\(trip.numberOfDays) day\(trip.numberOfDays == 1 ? "" : "s")"
        let stops = "\(stopCount) stop\(stopCount == 1 ? "" : "s")"
        return "\(days) · \(stops)"
    }

    /// Formats the trip date range for display (single date for one-day trips).
    private var formattedDateRange: String {
        if trip.numberOfDays <= 1 {
            return Trip.utcDateFormatter(format: "EEE, MMM d, yyyy").string(from: trip.startDate)
        }
        let start = Trip.utcDateFormatter(format: "MMM d").string(from: trip.startDate)
        let end = Trip.utcDateFormatter(format: "MMM d, yyyy").string(from: trip.endDate)
        return "\(start) – \(end)"
    }

    /// Overlapping avatar circles for trip collaborators.
    private var collaboratorAvatars: some View {
        HStack(spacing: avatarOverlap) {
            ForEach(collaborators.prefix(maxAvatarsShown)) { collaborator in
                collaboratorAvatar(collaborator)
            }

            if collaborators.count > maxAvatarsShown {
                overflowBadge
            }
        }
    }

    /// Single collaborator avatar circle.
    private func collaboratorAvatar(_ collaborator: LightweightCollaborator) -> some View {
        Group {
            if let urlString = collaborator.profilePhotoUrl,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Color.gray.opacity(0.3))
                }
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundStyle(.gray.opacity(0.5))
            }
        }
        .frame(width: avatarSize, height: avatarSize)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
    }

    /// "+N" badge when there are more collaborators than the max shown.
    private var overflowBadge: some View {
        Text("+\(collaborators.count - maxAvatarsShown)")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: avatarSize, height: avatarSize)
            .background(Color(.systemGray5))
            .clipShape(Circle())
            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
    }
}
