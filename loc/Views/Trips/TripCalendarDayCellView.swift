//
//  TripCalendarDayCellView.swift
//  loc
//
//  Single calendar cell showing day number, colored event dots, and acting as a drop target
//

import SwiftUI

/// Renders a single day cell in the trip calendar grid (Apple Calendar style).
struct TripCalendarDayCellView: View {
    let cell: CalendarGridData.Cell
    let dotColors: [Color]
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

    /// Tappable day cell with date number and colored event dots.
    private var dayContent: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text("\(cell.dayOfMonth ?? 0)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                placeDotsIndicator
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fill)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isTargeted ? Color.accentColor.opacity(0.12) : Color.clear)
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

    /// Up to 3 colored dots indicating places assigned to this day.
    private var placeDotsIndicator: some View {
        HStack(spacing: 3) {
            ForEach(Array(dotColors.prefix(3).enumerated()), id: \.offset) { _, color in
                Circle()
                    .fill(color)
                    .frame(width: 5, height: 5)
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
