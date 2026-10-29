//
//  GroupPickResultView.swift
//  loc
//
//  DUMB: the decided state of a group pick. Winner card with how it was
//  decided, Directions + Open place buttons, and who voted for it.
//

import SwiftUI

struct GroupPickResultView: View {
    let pick: GroupPick
    let winner: DetailPlace?
    let note: String?
    let currentUserId: String?
    let onOpenPlace: (DetailPlace) -> Void
    let onDirections: (DetailPlace) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            winnerCard
            if !pick.members.isEmpty, let winnerId = pick.decidedPlaceId {
                votersSection(winnerId: winnerId)
            }
        }
    }

    // MARK: - Winner

    private var winnerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                if let winner {
                    TonightPlaceThumbnail(place: winner, size: 72)
                } else {
                    SkeletonBlock(width: 72, height: 72, cornerRadius: 12)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(pick.outcome == .tieBreak ? "It was a tie 🤝" : "It's decided 🎉")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.green)
                    Text(winner?.name ?? "Loading…")
                        .font(.title3.weight(.bold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    if let address = winner?.address {
                        Text(address)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            if let note {
                Text(note)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            if let winner {
                HStack(spacing: 10) {
                    Button { onDirections(winner) } label: {
                        Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundColor(.white)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary))
                    }
                    .buttonStyle(.plain)
                    Button { onOpenPlace(winner) } label: {
                        Label("Place page", systemImage: "mappin.and.ellipse")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundColor(.primary)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(.systemGray5)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.green.opacity(0.12)))
    }

    // MARK: - Who voted

    private func votersSection(winnerId: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Who voted")
                .font(.subheadline.weight(.semibold))
            ForEach(pick.members) { member in
                HStack(spacing: 10) {
                    Text(initial(of: member))
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.primary.opacity(0.75)))
                    Text(label(for: member))
                        .font(.subheadline)
                    Spacer(minLength: 0)
                    voteBadge(member.vote(for: winnerId), votedCount: member.votedCount)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(.secondarySystemBackground)))
    }

    private func label(for member: GroupPickMember) -> String {
        let isMe = currentUserId?.lowercased() == member.userId.lowercased()
        return isMe ? "\(member.displayName) (you)" : member.displayName
    }

    private func initial(of member: GroupPickMember) -> String {
        String(member.displayName.prefix(1)).uppercased()
    }

    @ViewBuilder
    private func voteBadge(_ vote: Bool?, votedCount: Int) -> some View {
        if vote == true {
            Label("Yes", systemImage: "hand.thumbsup.fill")
                .font(.caption.weight(.semibold))
                .foregroundColor(.green)
        } else if vote == false {
            Label("No", systemImage: "hand.thumbsdown.fill")
                .font(.caption.weight(.semibold))
                .foregroundColor(.red)
        } else {
            Text(votedCount == 0 ? "Didn't vote" : "Skipped this one")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
