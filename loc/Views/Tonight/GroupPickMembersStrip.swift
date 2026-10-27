//
//  GroupPickMembersStrip.swift
//  loc
//
//  DUMB: "2 of 2 voted" with member avatars (a check on everyone who has
//  finished voting) and who the pick is still waiting on.
//

import SwiftUI

struct GroupPickMembersStrip: View {
    let pick: GroupPick
    let currentUserId: String?

    private var waiting: Set<String> { Set(pick.waitingOn.map { $0.lowercased() }) }

    /// Once a pick is decided, anyone who voted counts as done: an early decision
    /// (e.g. unanimous yes) can leave places nobody needed to vote on, and the server's
    /// waiting_on still lists those members.
    private func isDone(_ member: GroupPickMember) -> Bool {
        if pick.isDecided { return member.votedCount > 0 || !waiting.contains(member.userId.lowercased()) }
        return !waiting.contains(member.userId.lowercased())
    }

    private var doneCount: Int {
        pick.members.filter(isDone).count
    }

    private var waitingLine: String? {
        guard !pick.isDecided else { return nil }
        let names = pick.members
            .filter { waiting.contains($0.userId.lowercased()) }
            .map { isMe($0) ? "you" : $0.displayName }
        switch names.count {
        case 0: return nil
        case 1: return "Waiting on \(names[0])"
        case 2: return "Waiting on \(names[0]) and \(names[1])"
        default: return "Waiting on \(names[0]) and \(names.count - 1) others"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: -8) {
                ForEach(pick.members.prefix(6)) { member in
                    avatar(member)
                }
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("\(doneCount) of \(pick.members.count) voted")
                    .font(.subheadline.weight(.semibold))
                if let waitingLine {
                    Text(waitingLine)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private func isMe(_ member: GroupPickMember) -> Bool {
        currentUserId?.lowercased() == member.userId.lowercased()
    }

    private func avatar(_ member: GroupPickMember) -> some View {
        let done = isDone(member)
        return Text(String(member.displayName.prefix(1)).uppercased())
            .font(.caption.weight(.bold))
            .foregroundColor(.white)
            .frame(width: 30, height: 30)
            .background(Circle().fill(Color(hue: Double(abs(member.id.hashValue) % 360) / 360.0, saturation: 0.5, brightness: 0.7)))
            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
            .overlay(alignment: .bottomTrailing) {
                if done {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                        .background(Circle().fill(Color(.systemBackground)))
                        .offset(x: 3, y: 3)
                }
            }
            .opacity(done ? 1 : 0.55)
    }
}
