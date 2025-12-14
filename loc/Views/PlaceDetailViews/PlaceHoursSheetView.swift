//
//  PlaceHoursSheetView.swift
//  loc
//
//  Created by Cursor on 12/14/24.
//  Sheet view displaying place opening hours.
//  Pure display component - receives formatted data, no business logic.
//

import SwiftUI

struct PlaceHoursSheetView: View {
    
    // MARK: - Properties
    
    let placeName: String
    let openHours: [String]?
    let currentStatus: OpenStatus
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 0) {
                // Current Status Header
                currentStatusHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                
                Divider()
                
                // Hours List
                if let hours = openHours, !hours.isEmpty {
                    hoursListContent(hours: hours)
                } else {
                    noHoursAvailableView
                }
                
                Spacer()
            }
            .navigationTitle("Hours")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var currentStatusHeader: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
            
            Text(currentStatus.displayText.isEmpty ? "Status Unknown" : currentStatus.displayText)
                .font(.headline)
                .foregroundColor(statusColor)
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private func hoursListContent(hours: [String]) -> some View {
        let formattedHours = HoursFormatter.formatHours(hours)
        
        if formattedHours.isEmpty {
            noHoursAvailableView
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(formattedHours, id: \.day) { dayHours in
                        HourRowView(
                            dayHours: dayHours,
                            isToday: dayHours.isToday
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
        }
    }
    
    private var noHoursAvailableView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "clock")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.5))
            Text("Hours not available")
                .font(.subheadline)
                .foregroundColor(.gray)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Computed Properties
    
    private var statusColor: Color {
        switch currentStatus {
        case .open, .alwaysOpen:
            return .green
        case .closingSoon:
            return .orange
        case .openingSoon:
            return .blue
        case .closed:
            return .red
        case .temporarilyClosed, .permanentlyClosed:
            return .gray
        case .unknown:
            return .gray
        }
    }
}

// MARK: - Hour Row View

private struct HourRowView: View {
    let dayHours: DayHours
    let isToday: Bool
    
    var body: some View {
        HStack {
            Text(dayHours.day)
                .font(.body)
                .fontWeight(isToday ? .semibold : .regular)
                .foregroundColor(isToday ? .primary : .secondary)
                .frame(width: 100, alignment: .leading)
            
            Spacer()
            
            Text(dayHours.hours)
                .font(.body)
                .fontWeight(isToday ? .semibold : .regular)
                .foregroundColor(dayHours.isClosed ? .red : (isToday ? .primary : .secondary))
        }
        .padding(.vertical, 12)
        .background(isToday ? Color.blue.opacity(0.08) : Color.clear)
        .cornerRadius(8)
    }
}

// MARK: - Hours Formatter

struct DayHours: Identifiable {
    let id = UUID()
    let day: String
    let hours: String
    let isToday: Bool
    let isClosed: Bool
}

struct HoursFormatter {
    
    private static let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    private static let shortDayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    /// Formats raw openHours data into display-friendly format
    static func formatHours(_ openHours: [String]) -> [DayHours] {
        guard let first = openHours.first else { return [] }
        
        // Handle special status strings
        switch first {
        case "always_opened":
            return createAllDaysHours(hours: "Open 24 hours")
        case "temporarily_closed":
            return createAllDaysHours(hours: "Temporarily Closed", isClosed: true)
        case "permanently_closed":
            return createAllDaysHours(hours: "Permanently Closed", isClosed: true)
        default:
            return parsePeriodsToHours(openHours)
        }
    }
    
    private static func createAllDaysHours(hours: String, isClosed: Bool = false) -> [DayHours] {
        let today = getCurrentDayIndex()
        return (0..<7).map { index in
            // Reorder to start from today's day of week
            let dayIndex = (index + today) % 7
            return DayHours(
                day: dayNames[dayIndex],
                hours: hours,
                isToday: index == 0,
                isClosed: isClosed
            )
        }
    }
    
    private static func parsePeriodsToHours(_ openHours: [String]) -> [DayHours] {
        // Group periods by day
        var dayPeriods: [Int: [(open: String, close: String)]] = [:]
        
        for periodString in openHours {
            guard periodString.contains("-"), !periodString.hasPrefix("note:") else { continue }
            
            let components = periodString.split(separator: "-")
            guard components.count == 2 else { continue }
            
            let openParts = components[0].split(separator: ":")
            let closeParts = components[1].split(separator: ":")
            
            guard openParts.count == 3, closeParts.count == 3,
                  let openDay = Int(openParts[0]),
                  let openHour = Int(openParts[1]),
                  let openMinute = Int(openParts[2]),
                  let closeHour = Int(closeParts[1]),
                  let closeMinute = Int(closeParts[2]) else {
                continue
            }
            
            let openTime = formatTime(hour: openHour, minute: openMinute)
            let closeTime = formatTime(hour: closeHour, minute: closeMinute)
            
            // Day index is 1-7 (Sunday=1), convert to 0-6
            let dayIndex = openDay - 1
            if dayPeriods[dayIndex] == nil {
                dayPeriods[dayIndex] = []
            }
            dayPeriods[dayIndex]?.append((open: openTime, close: closeTime))
        }
        
        let today = getCurrentDayIndex()
        
        // Create DayHours for each day, starting from today
        return (0..<7).map { offset in
            let dayIndex = (today + offset) % 7
            let periods = dayPeriods[dayIndex] ?? []
            
            let hoursString: String
            let isClosed: Bool
            
            if periods.isEmpty {
                hoursString = "Closed"
                isClosed = true
            } else {
                hoursString = periods.map { "\($0.open) – \($0.close)" }.joined(separator: ", ")
                isClosed = false
            }
            
            return DayHours(
                day: dayNames[dayIndex],
                hours: hoursString,
                isToday: offset == 0,
                isClosed: isClosed
            )
        }
    }
    
    private static func formatTime(hour: Int, minute: Int) -> String {
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        
        if minute == 0 {
            return "\(displayHour) \(period)"
        } else {
            return String(format: "%d:%02d %@", displayHour, minute, period)
        }
    }
    
    private static func getCurrentDayIndex() -> Int {
        let calendar = Calendar.current
        // weekday is 1-7 (Sunday=1), we need 0-6 (Sunday=0)
        return calendar.component(.weekday, from: Date()) - 1
    }
}

// MARK: - Preview

#Preview("With Hours") {
    PlaceHoursSheetView(
        placeName: "Sample Restaurant",
        openHours: [
            "1:9:0-1:21:0",   // Sunday 9 AM - 9 PM
            "2:11:0-2:22:0",  // Monday 11 AM - 10 PM
            "3:11:0-3:22:0",  // Tuesday 11 AM - 10 PM
            "4:11:0-4:22:0",  // Wednesday 11 AM - 10 PM
            "5:11:0-5:23:0",  // Thursday 11 AM - 11 PM
            "6:11:0-6:23:30", // Friday 11 AM - 11:30 PM
            "7:10:0-7:23:30"  // Saturday 10 AM - 11:30 PM
        ],
        currentStatus: .open
    )
}

#Preview("Always Open") {
    PlaceHoursSheetView(
        placeName: "24/7 Store",
        openHours: ["always_opened"],
        currentStatus: .alwaysOpen
    )
}

#Preview("Closed") {
    PlaceHoursSheetView(
        placeName: "Closed Place",
        openHours: ["temporarily_closed"],
        currentStatus: .temporarilyClosed
    )
}

#Preview("No Hours") {
    PlaceHoursSheetView(
        placeName: "Unknown Place",
        openHours: nil,
        currentStatus: .unknown
    )
}
