//
//  TableSearchWindow.swift
//  loc
//
//  The day and time window a "Find a table" search covers, with the defaults and presets the sheet offers,
//  plus the pure formatting helpers used to build the request.
//

import Foundation

// MARK: - Window

/// A time window within one day, in minutes after midnight.
struct TableSearchWindow: Equatable {
    var startMinutes: Int
    var endMinutes: Int

    /// Latest end of the default window (10:30 PM).
    static let defaultEndMinutes = 22 * 60 + 30
    /// Start of the "Tomorrow" window and of the fallback window late at night (5:00 PM).
    static let eveningStartMinutes = 17 * 60

    /// True when the window ends after it starts.
    var isValid: Bool { endMinutes > startMinutes }

    /// The earliest half-hour mark at or after `date`, in minutes after midnight (may be 1440 or more at the end of the day).
    static func nextHalfHour(after date: Date, calendar: Calendar = .current) -> Int {
        let parts = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        let minuteOfDay = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        let hasRemainder = (parts.second ?? 0) > 0 || (parts.nanosecond ?? 0) > 0
        let rounded = (minuteOfDay / 30) * 30
        return (minuteOfDay % 30 == 0 && !hasRemainder) ? rounded : rounded + 30
    }
}

// MARK: - Selection

/// A day plus a time window.
struct TableSearchSelection: Equatable {
    var date: Date
    var window: TableSearchWindow

    /// Tonight: today from the next half hour through 10:30 PM. When that window is already over,
    /// falls back to tomorrow evening so the default is always searchable.
    static func tonight(now: Date, calendar: Calendar = .current) -> TableSearchSelection {
        let start = TableSearchWindow.nextHalfHour(after: now, calendar: calendar)
        guard start < TableSearchWindow.defaultEndMinutes else { return tomorrow(now: now, calendar: calendar) }
        return TableSearchSelection(
            date: calendar.startOfDay(for: now),
            window: TableSearchWindow(startMinutes: start, endMinutes: TableSearchWindow.defaultEndMinutes)
        )
    }

    /// Tomorrow from 5:00 PM through 10:30 PM.
    static func tomorrow(now: Date, calendar: Calendar = .current) -> TableSearchSelection {
        let today = calendar.startOfDay(for: now)
        let day = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        return TableSearchSelection(
            date: day,
            window: TableSearchWindow(startMinutes: TableSearchWindow.eveningStartMinutes, endMinutes: TableSearchWindow.defaultEndMinutes)
        )
    }
}

// MARK: - Formatting

/// Pure string conversions for the availability API.
enum TableTimeFormat {
    /// "YYYY-MM-DD" for a day, using the calendar's own year, month and day.
    static func dateString(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// "HH:MM" (24-hour) for minutes after midnight, clamped to the day.
    static func clockString(minutes: Int) -> String {
        let clamped = min(max(minutes, 0), 24 * 60 - 1)
        return String(format: "%02d:%02d", clamped / 60, clamped % 60)
    }

    /// Minutes after midnight for an "HH:MM" string; nil when it is not a valid time.
    static func minutes(fromClock clock: String) -> Int? {
        let parts = clock.split(separator: ":")
        guard parts.count >= 2, let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0..<24).contains(hour), (0..<60).contains(minute) else { return nil }
        return hour * 60 + minute
    }
}
