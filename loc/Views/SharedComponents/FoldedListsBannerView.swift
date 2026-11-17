//
//  FoldedListsBannerView.swift
//  loc
//
//  DUMB Component: one-time banner after city/type lists are folded into their cities, with Undo.
//

import SwiftUI

struct FoldedListsBannerView: View {
    let title: String
    let onUndo: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "square.stack.3d.up.fill")
                .foregroundColor(.mesaAccent)
            Text(title)
                .font(.footnote)
                .foregroundColor(.secondary)
                .lineLimit(2)
            Spacer(minLength: 8)
            Button("Undo", action: onUndo)
                .font(.footnote.weight(.semibold))
                .foregroundColor(.mesaAccent)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.mesaAccent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}
