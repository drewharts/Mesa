//
//  FindTableButton.swift
//  loc
//
//  DUMB Component: the compact, filled "Find a table" call to action shown beside a list's creator and
//  place count (lists with reservable places). The smaller FindTableChip stays in the chip row for an active search.
//

import SwiftUI

struct FindTableButton: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: "fork.knife")
                Text("Find a table")
                    .lineLimit(1)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.mesaAccent))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Search this list for open tables")
        .accessibilityIdentifier("list.findTable")
    }
}
