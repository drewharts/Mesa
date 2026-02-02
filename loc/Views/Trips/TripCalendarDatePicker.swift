//
//  TripCalendarDatePicker.swift
//  loc
//
//  iOS-style calendar picker for selecting trip date ranges.
//

import SwiftUI

/// iOS-style calendar for selecting trip date ranges using UICalendarView.
struct TripCalendarDatePicker: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Environment(\.dismiss) private var dismiss

    @State private var isSelectingStartDate: Bool = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                selectionHeader
                calendarView
                Spacer()
                doneButton
            }
            .padding()
            .navigationTitle("Select Dates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    /// Header showing which date is being selected.
    private var selectionHeader: some View {
        HStack(spacing: 20) {
            DateSelectionCard(
                label: "Start",
                date: startDate,
                isSelected: isSelectingStartDate
            )
            .onTapGesture { isSelectingStartDate = true }

            Image(systemName: "arrow.right")
                .foregroundColor(.gray)

            DateSelectionCard(
                label: "End",
                date: endDate,
                isSelected: !isSelectingStartDate
            )
            .onTapGesture { isSelectingStartDate = false }
        }
    }

    /// Calendar view wrapper.
    private var calendarView: some View {
        CalendarViewRepresentable(
            startDate: $startDate,
            endDate: $endDate,
            isSelectingStartDate: $isSelectingStartDate
        )
        .frame(height: 350)
    }

    /// Done button to confirm selection.
    private var doneButton: some View {
        Button(action: { dismiss() }) {
            Text("Done")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
        }
    }
}
