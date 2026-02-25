//
//  DateRangeDayCellView.swift
//  loc
//
//  Single calendar cell for the date range picker showing day number with visual selection state
//

import SwiftUI

/// Renders a single day cell in the date range picker calendar grid.
struct DateRangeDayCellView: View {
    let cell: DayCell
    let visualState: DayCellVisualState
    let onTap: () -> Void

    private let mesaCharcoal = Color(red: 45/255, green: 45/255, blue: 45/255)

    var body: some View {
        switch visualState {
        case .placeholder:
            Color.clear
                .frame(height: 44)
        case .disabled:
            disabledContent
        default:
            tappableContent
        }
    }

    // MARK: - Tappable Day Content

    private var tappableContent: some View {
        Button(action: onTap) {
            dayLabel
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(backgroundForState)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Disabled Day Content

    private var disabledContent: some View {
        Text("\(cell.dayOfMonth ?? 0)")
            .font(.body)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
    }

    // MARK: - Day Label

    private var dayLabel: some View {
        Text("\(cell.dayOfMonth ?? 0)")
            .font(.body)
            .fontWeight(isEndpoint ? .bold : .regular)
            .foregroundStyle(isEndpoint ? .white : .primary)
    }

    // MARK: - Styling Helpers

    private var isEndpoint: Bool {
        visualState == .startDate || visualState == .endDate
    }

    @ViewBuilder
    private var backgroundForState: some View {
        switch visualState {
        case .startDate, .endDate:
            Circle()
                .fill(mesaCharcoal)
        case .inRange:
            Rectangle()
                .fill(mesaCharcoal.opacity(0.08))
        default:
            Color.clear
        }
    }
}
