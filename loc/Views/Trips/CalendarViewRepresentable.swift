//
//  CalendarViewRepresentable.swift
//  loc
//
//  UIViewRepresentable wrapper for UICalendarView.
//

import SwiftUI
import UIKit

/// UIViewRepresentable wrapper for UICalendarView.
struct CalendarViewRepresentable: UIViewRepresentable {
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var isSelectingStartDate: Bool

    /// Creates the UICalendarView with proper configuration.
    func makeUIView(context: Context) -> UICalendarView {
        let calendarView = UICalendarView()
        calendarView.calendar = Calendar.current
        calendarView.locale = Locale.current
        calendarView.fontDesign = .rounded
        calendarView.delegate = context.coordinator
        calendarView.selectionBehavior = UICalendarSelectionSingleDate(delegate: context.coordinator)

        // Set visible date components to current month
        let today = Date()
        calendarView.visibleDateComponents = Calendar.current.dateComponents([.year, .month], from: today)

        return calendarView
    }

    /// Updates the UICalendarView when SwiftUI state changes.
    func updateUIView(_ uiView: UICalendarView, context: Context) {
        // Update coordinator with latest bindings
        context.coordinator.startDate = startDate
        context.coordinator.endDate = endDate
        context.coordinator.isSelectingStartDate = isSelectingStartDate
        context.coordinator.onStartDateChange = { startDate = $0 }
        context.coordinator.onEndDateChange = { endDate = $0 }
        context.coordinator.onToggleSelection = { isSelectingStartDate = $0 }

        // Force decoration refresh
        uiView.reloadDecorations(forDateComponents: visibleDateComponents(for: uiView), animated: false)
    }

    /// Creates the coordinator for handling calendar delegation.
    func makeCoordinator() -> Coordinator {
        Coordinator(
            startDate: startDate,
            endDate: endDate,
            isSelectingStartDate: isSelectingStartDate,
            onStartDateChange: { startDate = $0 },
            onEndDateChange: { endDate = $0 },
            onToggleSelection: { isSelectingStartDate = $0 }
        )
    }

    /// Visible date components for the calendar view.
    private var visibleMonthDateComponents: [DateComponents] {
        []
    }

    // MARK: - Private Helpers

    /// Returns date components for visible dates to refresh decorations.
    private func visibleDateComponents(for calendarView: UICalendarView) -> [DateComponents] {
        var components: [DateComponents] = []
        let calendar = Calendar.current

        // Get the visible month
        let visibleComponents = calendarView.visibleDateComponents
        guard let year = visibleComponents.year, let month = visibleComponents.month else {
            return []
        }

        // Get all days in the visible month
        var dateComponents = DateComponents()
        dateComponents.year = year
        dateComponents.month = month

        guard let monthStart = calendar.date(from: dateComponents),
              let range = calendar.range(of: .day, in: .month, for: monthStart) else {
            return []
        }

        for day in range {
            var dayComponents = DateComponents()
            dayComponents.year = year
            dayComponents.month = month
            dayComponents.day = day
            components.append(dayComponents)
        }

        return components
    }
}

// MARK: - Coordinator

extension CalendarViewRepresentable {
    /// Coordinator handling UICalendarView delegation.
    class Coordinator: NSObject, UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate {
        var startDate: Date
        var endDate: Date
        var isSelectingStartDate: Bool
        var onStartDateChange: (Date) -> Void
        var onEndDateChange: (Date) -> Void
        var onToggleSelection: (Bool) -> Void

        /// Initializes the coordinator with date state and callbacks.
        init(
            startDate: Date,
            endDate: Date,
            isSelectingStartDate: Bool,
            onStartDateChange: @escaping (Date) -> Void,
            onEndDateChange: @escaping (Date) -> Void,
            onToggleSelection: @escaping (Bool) -> Void
        ) {
            self.startDate = startDate
            self.endDate = endDate
            self.isSelectingStartDate = isSelectingStartDate
            self.onStartDateChange = onStartDateChange
            self.onEndDateChange = onEndDateChange
            self.onToggleSelection = onToggleSelection
        }

        /// Provides decorations for dates in the calendar.
        func calendarView(_ calendarView: UICalendarView, decorationFor dateComponents: DateComponents) -> UICalendarView.Decoration? {
            guard let date = Calendar.current.date(from: dateComponents) else {
                return nil
            }

            let calendar = Calendar.current
            let isStart = calendar.isDate(date, inSameDayAs: startDate)
            let isEnd = calendar.isDate(date, inSameDayAs: endDate)
            let isInRange = date >= calendar.startOfDay(for: startDate) && date <= calendar.startOfDay(for: endDate)

            if isStart || isEnd {
                return .customView {
                    let view = UIView()
                    view.backgroundColor = .systemBlue
                    view.layer.cornerRadius = 4
                    return view
                }
            } else if isInRange {
                return .customView {
                    let view = UIView()
                    view.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.2)
                    return view
                }
            }

            return nil
        }

        /// Handles date selection in the calendar.
        func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
            guard let dateComponents = dateComponents,
                  let date = Calendar.current.date(from: dateComponents) else {
                return
            }

            if isSelectingStartDate {
                onStartDateChange(date)
                if date > endDate {
                    onEndDateChange(date)
                }
                onToggleSelection(false)
            } else {
                if date >= startDate {
                    onEndDateChange(date)
                } else {
                    // User selected a date before start, make it the new start
                    onStartDateChange(date)
                }
                onToggleSelection(true)
            }
        }
    }
}
