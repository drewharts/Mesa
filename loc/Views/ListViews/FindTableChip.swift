//
//  FindTableChip.swift
//  loc
//
//  DUMB Component: the "Find a table" entry chip at the start of a list's chip row.
//  Filled while a table search is narrowing the list.
//

import SwiftUI

struct FindTableChip: View {
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Label("Find a table", systemImage: "fork.knife")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(isActive ? .white : Color.mesaAccent)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(isActive ? Color.mesaAccent : Color.mesaAccent.opacity(0.12)))
        }
        .accessibilityHint("Search this list for open tables")
    }
}
