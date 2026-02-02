//
//  DateSelectionCard.swift
//  loc
//
//  Individual date card for trip date selection.
//

import SwiftUI

/// Displays a selectable date card showing label and formatted date.
struct DateSelectionCard: View {
    let label: String
    let date: Date
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            labelText
            dateText
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
        .cornerRadius(10)
        .overlay(selectionBorder)
    }

    /// The label text above the date.
    private var labelText: some View {
        Text(label)
            .font(.caption)
            .foregroundColor(.gray)
    }

    /// The formatted date text.
    private var dateText: some View {
        Text(formattedDate)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(isSelected ? .blue : .black)
    }

    /// Border overlay when selected.
    private var selectionBorder: some View {
        RoundedRectangle(cornerRadius: 10)
            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
    }

    /// Formats the date for display.
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}
