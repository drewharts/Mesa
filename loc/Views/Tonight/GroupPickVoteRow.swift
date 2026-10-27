//
//  GroupPickVoteRow.swift
//  loc
//
//  DUMB: one place in a group pick with one-tap yes/no and the live tally.
//

import SwiftUI

struct GroupPickVoteRow: View {
    let name: String
    let place: DetailPlace?
    let tally: GroupPickTally
    let myVote: Bool?
    let isWinner: Bool
    let isDecided: Bool
    let onVote: (Bool) -> Void
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
                        Text("\(tally.yes) yes · \(tally.no) no")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
            if isDecided {
                if isWinner {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                }
            } else {
                voteButton(yes: false)
                voteButton(yes: true)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isWinner ? Color.green.opacity(0.12) : Color(.secondarySystemBackground))
        )
    }

    private func voteButton(yes: Bool) -> some View {
        let selected = myVote == yes
        return Button { onVote(yes) } label: {
            Image(systemName: yes ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(selected ? .white : .secondary)
                .frame(width: 42, height: 42)
                .background(Circle().fill(selected ? (yes ? Color.green : Color.red) : Color(.systemGray5)))
        }
        .buttonStyle(.plain)
    }
}
