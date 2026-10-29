//
//  GroupPickRankRow.swift
//  loc
//
//  DUMB: one place in a planned group pick. Tap the badge to give it your next
//  rank (1st/2nd/3rd) or remove it; shows the live Borda points.
//

import SwiftUI

struct GroupPickRankRow: View {
    let name: String
    let place: DetailPlace?
    let standing: GroupPickStanding?
    let myRank: Int?
    let isWinner: Bool
    let isDecided: Bool
    let onToggle: () -> Void
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onOpen) {
                HStack(spacing: 12) {
                    if let place {
                        TonightPlaceThumbnail(place: place, size: 52)
                    } else {
                        SkeletonBlock(width: 52, height: 52, cornerRadius: 12)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(name)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        if let place, let category = TonightRanker.displayCategory(for: place) {
                            Text(category)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        Text(pointsText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
            if isWinner {
                Text("🏆").font(.title2)
            } else if !isDecided {
                Button(action: onToggle) {
                    ZStack {
                        Circle()
                            .fill(myRank == nil ? Color(.systemGray5) : Color.primary)
                            .frame(width: 40, height: 40)
                        if let myRank {
                            Text(GroupPickRankRow.ordinal(myRank))
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(Color(.systemBackground))
                        } else {
                            Image(systemName: "plus").foregroundColor(.primary)
                        }
                    }
                    .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(myRank.map { "Ranked \(GroupPickRankRow.ordinal($0)). Tap to remove." } ?? "Rank this place")
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isWinner ? Color.primary : Color.clear, lineWidth: 2)
        )
    }

    private var pointsText: String {
        guard let standing, standing.points > 0 else { return "No votes yet" }
        return "\(standing.points) pts · \(standing.voters) \(standing.voters == 1 ? "vote" : "votes")"
    }

    static func ordinal(_ rank: Int) -> String {
        switch rank {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(rank)th"
        }
    }
}

/// DUMB: live (or final) top 3 of a planned pick with points and vote counts.
struct GroupPickPodiumView: View {
    let pick: GroupPick
    let note: String?
    let placeName: (String) -> String
    let winner: DetailPlace?
    let onOpenWinner: () -> Void
    let onDirections: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(pick.isDecided ? "Final results" : "Live results")
                    .font(.headline)
                Spacer()
                if !pick.isDecided {
                    Label("Live", systemImage: "dot.radiowaves.left.and.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.green)
                }
            }
            if pick.podium.isEmpty {
                Text("No rankings yet. Be the first.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(pick.podium.enumerated()), id: \.element.placeId) { index, s in
                    HStack(spacing: 10) {
                        Text(["🥇", "🥈", "🥉"][index]).font(.title3)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(placeName(s.placeId))
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Text("\(s.first)× 1st · \(s.second)× 2nd · \(s.third)× 3rd")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("\(s.points) pts")
                            .font(.subheadline.weight(.bold))
                            .monospacedDigit()
                    }
                }
            }
            if let note {
                Text(note).font(.footnote).foregroundColor(.secondary)
            }
            if pick.isDecided, winner != nil {
                HStack(spacing: 8) {
                    Button(action: onOpenWinner) {
                        Text("View place")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundColor(.primary)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(.systemGray5)))
                    }
                    Button(action: onDirections) {
                        Text("Directions")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundColor(Color(.systemBackground))
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary))
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.secondarySystemBackground)))
    }
}
