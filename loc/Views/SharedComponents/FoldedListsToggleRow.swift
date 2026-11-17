//
//  FoldedListsToggleRow.swift
//  loc
//
//  DUMB Component: "Show folded lists" toggle (plus Restore all while they are shown).
//

import SwiftUI

struct FoldedListsToggleRow: View {
    let title: String
    let isShowing: Bool
    let onToggle: () -> Void
    let onRestoreAll: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button(action: onToggle) {
                Text(title)
                    .font(.footnote.weight(.medium))
                    .foregroundColor(.secondary)
            }
            if isShowing {
                Button("Restore all", action: onRestoreAll)
                    .font(.footnote.weight(.medium))
                    .foregroundColor(.mesaAccent)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
    }
}
