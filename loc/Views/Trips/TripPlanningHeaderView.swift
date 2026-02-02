//
//  TripPlanningHeaderView.swift
//  loc
//
//  Header view displaying trip summary information.
//

import SwiftUI

/// Displays trip summary with date range, day count, and place count.
struct TripPlanningHeaderView: View {
    let dateRange: String
    let numberOfDays: Int
    let totalPlaces: Int

    var body: some View {
        VStack(spacing: 8) {
            dateRangeLabel
            statsRow
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemBackground))
    }

    /// Displays the formatted date range.
    private var dateRangeLabel: some View {
        Text(dateRange)
            .font(.headline)
            .foregroundColor(.primary)
    }

    /// Displays day count and place count statistics.
    private var statsRow: some View {
        HStack(spacing: 16) {
            statItem(value: numberOfDays, label: numberOfDays == 1 ? "Day" : "Days")
            statItem(value: totalPlaces, label: totalPlaces == 1 ? "Place" : "Places")
        }
    }

    /// Creates a single stat display item.
    private func statItem(value: Int, label: String) -> some View {
        HStack(spacing: 4) {
            Text("\(value)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}
