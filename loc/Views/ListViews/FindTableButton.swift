//
//  FindTableButton.swift
//  loc
//
//  DUMB Component: the prominent, filled "Find a table" call to action shown near a list's header
//  (lists with reservable places). The smaller FindTableChip stays in the chip row for an active search.
//

import SwiftUI

struct FindTableButton: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: "fork.knife")
                Text("Find a table")
                Spacer(minLength: 8)
                Text("Live Resy availability")
                    .font(.caption)
                    .opacity(0.85)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(Capsule().fill(Color.mesaAccent))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .accessibilityHint("Search this list for open tables")
    }
}
