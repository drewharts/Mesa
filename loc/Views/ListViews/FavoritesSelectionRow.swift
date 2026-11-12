//
//  FavoritesSelectionRow.swift
//  loc
//
//  DUMB Component: Displays a "Favorites" row in the list selection sheet.
//  Styled to match LightweightListSelectionRowView.
//

import SwiftUI

/// Displays the "Favorites" row pinned at the top of the list selection sheet.
struct FavoritesSelectionRow: View {
    let isFavorited: Bool
    let onToggle: () -> Void
    /// PROTOTYPE (auto_sort_saved): `.autoSortSaved` shows the same row as "Saved".
    var style: Style = .favorites

    enum Style { case favorites, autoSortSaved }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Star icon
                Image(systemName: style == .autoSortSaved ? "square.stack.3d.up.fill" : "star.fill")
                    .font(.title3)
                    .foregroundColor(style == .autoSortSaved ? .mesaAccent : .yellow)
                    .frame(width: 32, height: 32)

                // Label
                if style == .autoSortSaved {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Saved")
                            .font(.body)
                            .foregroundStyle(Color.primary)
                        Text("Sorted by city and type")
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                    }
                } else {
                    Text("Favorites")
                        .font(.body)
                        .foregroundStyle(Color.primary)
                }

                Spacer()

                // Selection indicator (matches LightweightListSelectionRowView)
                ZStack {
                    if isFavorited {
                        Circle()
                            .fill(Color.primary)
                            .frame(width: 20, height: 20)
                    } else {
                        Circle()
                            .stroke(Color.primary, lineWidth: 1.5)
                            .frame(width: 20, height: 20)
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
