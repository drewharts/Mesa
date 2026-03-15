//
//  TripCalendarDayCellView.swift
//  loc
//
//  Single calendar cell showing day number, place dots, and acting as a drop target
//

import SwiftUI

/// Renders a single day cell in the trip calendar grid.
struct TripCalendarDayCellView: View {
    let cell: CalendarGridData.Cell
    let placeCount: Int
    let onTap: () -> Void
    let onDropPlace: ((String) -> Void)?

    @State private var isTargeted = false

    var body: some View {
        if cell.dayIndex != nil {
            dayContent
        } else {
            Color.clear
                .aspectRatio(1, contentMode: .fill)
        }
    }

    // MARK: - Day Content

    private var dayContent: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text("\(cell.dayOfMonth ?? 0)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                placeDotsIndicator
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fill)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isTargeted ? Color.accentColor.opacity(0.15) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isTargeted ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .modifier(PlaceDropModifier(onDropPlace: onDropPlace, isTargeted: $isTargeted))
    }

    // MARK: - Place Dots

    private var placeDotsIndicator: some View {
        HStack(spacing: 3) {
            if placeCount > 0 {
                let dotCount = min(placeCount, 3)
                ForEach(0..<dotCount, id: \.self) { _ in
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 5, height: 5)
                }
                if placeCount > 3 {
                    Text("+")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Drop Modifier

/// Conditionally applies dropDestination when drop is enabled.
private struct PlaceDropModifier: ViewModifier {
    let onDropPlace: ((String) -> Void)?
    @Binding var isTargeted: Bool

    func body(content: Content) -> some View {
        if let onDropPlace {
            content
                .dropDestination(for: String.self) { items, _ in
                    guard let placeId = items.first else { return false }
                    onDropPlace(placeId)
                    return true
                } isTargeted: { targeted in
                    isTargeted = targeted
                }
        } else {
            content
        }
    }
}
