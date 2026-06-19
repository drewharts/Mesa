//
//  FilterChip.swift
//  loc
//
//  DUMB Component: Google-style filter chip with selected/unselected states.
//  Single Responsibility: Render a labeled, tappable filter pill.
//

import SwiftUI

/// Google-style filter chip for category/filter selection.
struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.primary : Color(.systemGray6))
                )
        }
    }
}
