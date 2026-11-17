//
//  SavedFilterChip.swift
//  loc
//
//  DUMB Component: a pill with a title and a place count, used in a city's horizontally scrolling chip row.
//

import SwiftUI

struct SavedFilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Text(title).font(.subheadline.weight(.medium))
                Text("\(count)")
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundColor(isSelected ? .white : .primary)
            .background(isSelected ? Color.mesaAccent : Color(.secondarySystemBackground), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
