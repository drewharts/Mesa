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
/// Extracted from SelectedPlaceViewModel for single responsibility compliance.
struct OpenStatusService {
    
    // MARK: - Constants
    
    /// Minutes threshold for "closing soon" warning
    private static let closingSoonThresholdMinutes = 30
    
    /// Minutes threshold for "opening soon" notice
    private static let openingSoonThresholdMinutes = 30
    
    // MARK: - Public API
    
    /// Determines the current open status for a place.
    /// - Parameter place: The place to check status for
    /// - Returns: The current open status
    static func getStatus(for place: DetailPlace) -> OpenStatus {
        guard let openHours = place.openHours, !openHours.isEmpty else {
            return .unknown
        }
        
        return calculateStatus(from: openHours)
    }
    
    /// Determines if a place is currently open (simple boolean check).
    /// - Parameter place: The place to check
    /// - Returns: True if the place is currently open
    static func isOpen(_ place: DetailPlace) -> Bool {
        getStatus(for: place).isOpen
    }
    
    // MARK: - Private Implementation
    
    private static func calculateStatus(from openHours: [String]) -> OpenStatus {
        // Handle special status strings
        guard let firstEntry = openHours.first else { return .unknown }
        
        switch firstEntry {
        case "always_opened":
            return .alwaysOpen
        case "temporarily_closed":
            return .temporarilyClosed
        case "permanently_closed":
            return .permanentlyClosed
        default:
            return calculateStatusFromPeriods(openHours)
        }
    }
    
    private static func calculateStatusFromPeriods(_ openHours: [String]) -> OpenStatus {
        let now = Date()
        let calendar = Calendar.current
        let currentWeekday = calendar.component(.weekday, from: now) // Sunday=1, ..., Saturday=7
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentMinutesSinceWeekStart = ((currentWeekday - 1) * 24 * 60) + (currentHour * 60) + currentMinute
        
        var closestOpeningMinutes: Int?
        var closestClosingMinutes: Int?
        
        for periodString in openHours {
            guard let period = parsePeriod(periodString) else { continue }
            
            let (openMinutes, closeMinutes) = calculatePeriodMinutes(period: period)
            
            // Check if currently within this period
            if isWithinPeriod(current: currentMinutesSinceWeekStart, open: openMinutes, close: closeMinutes) {
                let minutesUntilClose = calculateMinutesUntil(
                    target: closeMinutes,
                    from: currentMinutesSinceWeekStart
                )
                
                if minutesUntilClose <= closingSoonThresholdMinutes {
                    return .closingSoon(minutesRemaining: minutesUntilClose)
                }
                return .open
            }
            
            // Track closest opening time for "opening soon"
            let minutesUntilOpen = calculateMinutesUntil(
                target: openMinutes,
                from: currentMinutesSinceWeekStart
            )
            if closestOpeningMinutes == nil || minutesUntilOpen < closestOpeningMinutes! {
                closestOpeningMinutes = minutesUntilOpen
            }
        }
        
        // Check if opening soon
        if let minutes = closestOpeningMinutes, minutes <= openingSoonThresholdMinutes {
            return .openingSoon(minutesRemaining: minutes)
        }
        
        return .closed
    }
    
    // MARK: - Period Parsing
    
    private struct OpenPeriod {
        let openDay: Int
        let openHour: Int
        let openMinute: Int
        let closeDay: Int
        let closeHour: Int
        let closeMinute: Int
    }
    
    private static func parsePeriod(_ periodString: String) -> OpenPeriod? {
        // Skip non-period strings
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
            openDay: openDay,
            openHour: openHour,
            openMinute: openMinute,
            closeDay: closeDay,
            closeHour: closeHour,
            closeMinute: closeMinute
        )
    }
    
    private static func calculatePeriodMinutes(period: OpenPeriod) -> (open: Int, close: Int) {
        let openMinutes = ((period.openDay - 1) * 24 * 60) + (period.openHour * 60) + period.openMinute
        var closeMinutes = ((period.closeDay - 1) * 24 * 60) + (period.closeHour * 60) + period.closeMinute
        
        // Handle overnight periods (e.g., 10 PM - 2 AM)
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
            // Wraps around to next week
            return (weekMinutes - current) + target
        }
    }
}
