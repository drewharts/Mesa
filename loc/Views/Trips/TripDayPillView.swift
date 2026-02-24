//
//  TripDayPillView.swift
//  loc
//
//  Single day pill with drop target support for the day selector
//

import SwiftUI

/// A tappable day pill that also acts as a drop target for cross-day drag.
struct TripDayPillView: View {
    let index: Int
    let isSelected: Bool
    let label: String
    let onSelect: () -> Void
    let onDropPlace: ((String, Int) -> Void)?

    @State private var isTargeted = false

    var body: some View {
        Button {
            onSelect()
        } label: {
            Text(label)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(pillBackground)
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.accentColor, lineWidth: isTargeted ? 2 : 0)
                )
        }
        .buttonStyle(.plain)
        .dropDestination(for: String.self) { items, _ in
            guard let entryId = items.first else { return false }
            onDropPlace?(entryId, index)
            return true
        } isTargeted: { targeted in
            withAnimation(.easeInOut(duration: 0.15)) {
                isTargeted = targeted
            }
        }
    }

    /// Returns the background color based on selection and drag-target state.
    private var pillBackground: Color {
        if isTargeted {
            return Color.accentColor.opacity(0.2)
        }
        return isSelected ? Color.accentColor : Color(.systemGray6)
    }
}
