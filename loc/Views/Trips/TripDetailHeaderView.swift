//
//  TripDetailHeaderView.swift
//  loc
//
//  Dumb view displaying trip name, date range, collaborator avatars, and summary info
//

import SwiftUI

/// Displays trip header info: name, date range, collaborator avatars, and day count.
struct TripDetailHeaderView: View {
    let trip: Trip
    let collaborators: [LightweightCollaborator]

    private let maxAvatarsShown = 4
    private let avatarSize: CGFloat = 28
    private let avatarOverlap: CGFloat = -8

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(formattedDateRange)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("\(trip.numberOfDays) day\(trip.numberOfDays == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if !collaborators.isEmpty {
                collaboratorAvatars
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    /// Formats the trip date range for display.
    private var formattedDateRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let start = formatter.string(from: trip.startDate)
        formatter.dateFormat = "MMM d, yyyy"
        let end = formatter.string(from: trip.endDate)
        return "\(start) - \(end)"
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
