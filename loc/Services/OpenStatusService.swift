//
//  OpenStatusService.swift
//  loc
//
//  Created by Cursor on 12/14/24.
//  Stateless service for determining place open/closed status.
//  Single Responsibility: Parses opening hours and determines current status.
//

import Foundation

// MARK: - Open Status Enum

/// Represents the current open/closed status of a place.
/// Provides all necessary information for UI display.
enum OpenStatus: Equatable {
    case open
    case closed
    case closingSoon(minutesRemaining: Int)
    case openingSoon(minutesRemaining: Int)
    case alwaysOpen
    case temporarilyClosed
    case permanentlyClosed
    case unknown
    
    // MARK: - Display Properties
    
    var displayText: String {
        switch self {
        case .open:
            return "Open"
        case .closed:
            return "Closed"
        case .closingSoon(let minutes):
            return "Closes in \(minutes)m"
        case .openingSoon(let minutes):
            return "Opens in \(minutes)m"
        case .alwaysOpen:
            return "Open 24/7"
        case .temporarilyClosed:
            return "Temporarily Closed"
        case .permanentlyClosed:
            return "Permanently Closed"
        case .unknown:
            return ""
        }
    }
    
    var isOpen: Bool {
        switch self {
        case .open, .closingSoon, .alwaysOpen:
            return true
        case .closed, .openingSoon, .temporarilyClosed, .permanentlyClosed, .unknown:
            return false
        }
    }
    
    var shouldDisplay: Bool {
        self != .unknown
    }
}

// MARK: - Open Status Service

/// Stateless service for calculating place open status from opening hours data.
/// Supports multiple hour formats:
/// - Period format: "1:9:0-1:21:0" (day:hour:minute-day:hour:minute)
/// - Human-readable format: "Monday: 12–9 PM"
/// - Special statuses: "always_opened", "temporarily_closed", "permanently_closed"
struct OpenStatusService {
    
    // MARK: - Constants
    
    private static let closingSoonThresholdMinutes = 30
    private static let openingSoonThresholdMinutes = 30
    
    private static let dayNameToIndex: [String: Int] = [
        "sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4,
        "thursday": 5, "friday": 6, "saturday": 7
    ]
    
    // MARK: - Public API
    
    /// Determines the current open status for a place.
    static func getStatus(for place: DetailPlace) -> OpenStatus {
        guard let openHours = place.openHours, !openHours.isEmpty else {
            return .unknown
        }
        
        return calculateStatus(from: openHours)
    }
    
    /// Determines if a place is currently open (simple boolean check).
    static func isOpen(_ place: DetailPlace) -> Bool {
        getStatus(for: place).isOpen
    }
    
    // MARK: - Private Implementation
    
    private static func calculateStatus(from openHours: [String]) -> OpenStatus {
        guard let firstEntry = openHours.first else { return .unknown }
        
        // Handle special status strings
        switch firstEntry.lowercased() {
        case "always_opened", "open 24 hours":
            return .alwaysOpen
        case "temporarily_closed":
            return .temporarilyClosed
        case "permanently_closed":
            return .permanentlyClosed
        default:
            break
        }
        
        // Detect format and parse accordingly
        if isHumanReadableFormat(firstEntry) {
            return calculateStatusFromHumanReadable(openHours)
        } else {
            return calculateStatusFromPeriods(openHours)
        }
    }
    
    /// Detects if hours are in human-readable format like "Monday: 12–9 PM"
    private static func isHumanReadableFormat(_ entry: String) -> Bool {
        // Check if it contains a day name followed by colon
        let lowercased = entry.lowercased()
        for dayName in dayNameToIndex.keys {
            if lowercased.hasPrefix(dayName) {
                return true
            }
        }
        return false
    }
    
    // MARK: - Human-Readable Format Parsing
    
    private static func calculateStatusFromHumanReadable(_ openHours: [String]) -> OpenStatus {
        let calendar = Calendar.current
        let now = Date()
        let currentWeekday = calendar.component(.weekday, from: now) // Sunday=1
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentTimeMinutes = currentHour * 60 + currentMinute
        
        // Find today's hours
        guard let todayHours = findHoursForDay(weekday: currentWeekday, in: openHours) else {
            return .unknown
        }
        
        // Check if closed today
        if todayHours.lowercased() == "closed" {
            // Check if opening tomorrow
            let tomorrowWeekday = (currentWeekday % 7) + 1
            if let tomorrowHours = findHoursForDay(weekday: tomorrowWeekday, in: openHours),
               tomorrowHours.lowercased() != "closed" {
                if let (openTime, _) = parseTimeRange(tomorrowHours) {
                    let minutesUntilMidnight = (24 * 60) - currentTimeMinutes
                    let totalMinutesUntilOpen = minutesUntilMidnight + openTime
                    if totalMinutesUntilOpen <= openingSoonThresholdMinutes {
                        return .openingSoon(minutesRemaining: totalMinutesUntilOpen)
                    }
                }
            }
            return .closed
        }
        
        // Parse today's time range
        guard let (openTime, closeTime) = parseTimeRange(todayHours) else {
            // If we can't parse but it's not "Closed", assume open
            return .open
        }
        
        // Check current status
        if currentTimeMinutes < openTime {
            // Before opening
            let minutesUntilOpen = openTime - currentTimeMinutes
            if minutesUntilOpen <= openingSoonThresholdMinutes {
                return .openingSoon(minutesRemaining: minutesUntilOpen)
            }
            return .closed
        } else if currentTimeMinutes < closeTime {
            // Currently open
            let minutesUntilClose = closeTime - currentTimeMinutes
            if minutesUntilClose <= closingSoonThresholdMinutes {
                return .closingSoon(minutesRemaining: minutesUntilClose)
            }
            return .open
        } else {
            // After closing
            return .closed
        }
    }
    
    /// Finds hours string for a given weekday from the openHours array
    private static func findHoursForDay(weekday: Int, in openHours: [String]) -> String? {
        let dayNames = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
        guard weekday >= 1 && weekday <= 7 else { return nil }
        let targetDay = dayNames[weekday - 1]
        
        for entry in openHours {
            let lowercased = entry.lowercased()
            if lowercased.hasPrefix(targetDay) {
                // Extract hours part after "Day: "
                if let colonIndex = entry.firstIndex(of: ":") {
                    let hoursStart = entry.index(after: colonIndex)
                    return String(entry[hoursStart...]).trimmingCharacters(in: .whitespaces)
                }
            }
        }
        return nil
    }
    
    /// Parses a time range string like "12–9 PM" or "11 AM–10 PM" into minutes from midnight
    private static func parseTimeRange(_ timeString: String) -> (open: Int, close: Int)? {
        // Handle various dash characters
        let normalizedString = timeString
            .replacingOccurrences(of: "–", with: "-")  // en-dash
            .replacingOccurrences(of: "—", with: "-")  // em-dash
            .trimmingCharacters(in: .whitespaces)
        
        // Split by dash
        let parts = normalizedString.split(separator: "-").map { String($0).trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2 else { return nil }
        
        let openString = parts[0]
        let closeString = parts[1]
        
        // Parse close time first to get the period (AM/PM)
        guard let closeTime = parseTime(closeString) else { return nil }
        
        // Parse open time, inheriting period from close if not specified
        let openTime: Int
        if openString.lowercased().contains("am") || openString.lowercased().contains("pm") {
            guard let parsed = parseTime(openString) else { return nil }
            openTime = parsed
        } else {
            // No period specified, infer based on close time
            guard let parsed = parseTimeInferringPeriod(openString, closeTime: closeTime) else { return nil }
            openTime = parsed
        }
        
        return (openTime, closeTime)
    }
    
    /// Parses a time string like "9 PM" or "11:30 AM" into minutes from midnight
    private static func parseTime(_ timeString: String) -> Int? {
        let cleaned = timeString.trimmingCharacters(in: .whitespaces)
        let isAM = cleaned.lowercased().contains("am")
        let isPM = cleaned.lowercased().contains("pm")
        
        guard isAM || isPM else { return nil }
        
        let numericPart = cleaned
            .replacingOccurrences(of: "AM", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "PM", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespaces)
        
        let timeParts = numericPart.split(separator: ":").map { String($0) }
        guard let hour = Int(timeParts[0]) else { return nil }
        let minute = timeParts.count > 1 ? (Int(timeParts[1]) ?? 0) : 0
        
        var hour24 = hour
        if isPM && hour != 12 {
            hour24 += 12
        } else if isAM && hour == 12 {
            hour24 = 0
        }
        
        return hour24 * 60 + minute
    }
    
    /// Parses a time without AM/PM, inferring based on context
    private static func parseTimeInferringPeriod(_ timeString: String, closeTime: Int) -> Int? {
        let cleaned = timeString.trimmingCharacters(in: .whitespaces)
        let timeParts = cleaned.split(separator: ":").map { String($0) }
        guard let hour = Int(timeParts[0]) else { return nil }
        let minute = timeParts.count > 1 ? (Int(timeParts[1]) ?? 0) : 0
        
        // Assume PM if the close time is in the evening (after noon)
        // and the open hour is less than 12
        let closeHour = closeTime / 60
        
        var hour24 = hour
        if closeHour >= 12 && hour <= 12 {
            // If close is PM and open hour is 12 or less, it's likely PM (noon opening)
            if hour != 12 {
                hour24 = hour + 12
            }
        }
        
        return hour24 * 60 + minute
    }
    
    // MARK: - Period Format Parsing (Legacy)
    
    private static func calculateStatusFromPeriods(_ openHours: [String]) -> OpenStatus {
        let now = Date()
        let calendar = Calendar.current
        let currentWeekday = calendar.component(.weekday, from: now)
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentMinutesSinceWeekStart = ((currentWeekday - 1) * 24 * 60) + (currentHour * 60) + currentMinute
        
        var closestOpeningMinutes: Int?
        
        for periodString in openHours {
            guard let period = parsePeriod(periodString) else { continue }
            
            let (openMinutes, closeMinutes) = calculatePeriodMinutes(period: period)
            
            if isWithinPeriod(current: currentMinutesSinceWeekStart, open: openMinutes, close: closeMinutes) {
                let minutesUntilClose = calculateMinutesUntil(target: closeMinutes, from: currentMinutesSinceWeekStart)
                
                if minutesUntilClose <= closingSoonThresholdMinutes {
                    return .closingSoon(minutesRemaining: minutesUntilClose)
                }
                return .open
            }
            
            let minutesUntilOpen = calculateMinutesUntil(target: openMinutes, from: currentMinutesSinceWeekStart)
            if closestOpeningMinutes == nil || minutesUntilOpen < closestOpeningMinutes! {
                closestOpeningMinutes = minutesUntilOpen
            }
        }
        
        if let minutes = closestOpeningMinutes, minutes <= openingSoonThresholdMinutes {
            return .openingSoon(minutesRemaining: minutes)
        }
        
        return .closed
    }
    
    private struct OpenPeriod {
        let openDay: Int
        let openHour: Int
        let openMinute: Int
        let closeDay: Int
        let closeHour: Int
        let closeMinute: Int
    }
    
    private static func parsePeriod(_ periodString: String) -> OpenPeriod? {
        guard periodString.contains("-"), !periodString.hasPrefix("note:") else {
            return nil
        }
        
        let components = periodString.split(separator: "-")
        guard components.count == 2 else { return nil }
        
        let openParts = components[0].split(separator: ":")
        let closeParts = components[1].split(separator: ":")
        
        guard openParts.count == 3, closeParts.count == 3,
              let openDay = Int(openParts[0]),
              let openHour = Int(openParts[1]),
              let openMinute = Int(openParts[2]),
              let closeDay = Int(closeParts[0]),
              let closeHour = Int(closeParts[1]),
              let closeMinute = Int(closeParts[2]) else {
            return nil
        }
        
        return OpenPeriod(
            openDay: openDay, openHour: openHour, openMinute: openMinute,
            closeDay: closeDay, closeHour: closeHour, closeMinute: closeMinute
        )
    }
    
    private static func calculatePeriodMinutes(period: OpenPeriod) -> (open: Int, close: Int) {
        let openMinutes = ((period.openDay - 1) * 24 * 60) + (period.openHour * 60) + period.openMinute
        var closeMinutes = ((period.closeDay - 1) * 24 * 60) + (period.closeHour * 60) + period.closeMinute
        
        if closeMinutes <= openMinutes {
            closeMinutes += 7 * 24 * 60
        }
        
        return (openMinutes, closeMinutes)
    }
    
    private static func isWithinPeriod(current: Int, open: Int, close: Int) -> Bool {
        current >= open && current <= close
    }
    
    private static func calculateMinutesUntil(target: Int, from current: Int) -> Int {
        let weekMinutes = 7 * 24 * 60
        if target >= current {
            return target - current
        } else {
            return (weekMinutes - current) + target
        }
    }
}
