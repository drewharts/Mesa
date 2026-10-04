//
//  Trip.swift
//  loc
//
//  Full trip model for detail views and editing
//

import Foundation

/// Full trip entity with all metadata fields.
struct Trip: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    let ownerId: String
    var coverImage: String?
    let createdAt: String?
    let updatedAt: String?

    // Stored as strings for reliable Supabase date decoding ("yyyy-MM-dd")
    private let startDateRaw: String
    private let endDateRaw: String

    /// Parsed start date.
    var startDate: Date {
        Self.parseDate(startDateRaw) ?? Date()
    }

    /// Parsed end date.
    var endDate: Date {
        Self.parseDate(endDateRaw) ?? Date()
    }

    /// Returns the inclusive number of days in this trip.
    var numberOfDays: Int {
        let days = Self.utcCalendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        return max(days + 1, 1)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case ownerId = "owner_id"
        case startDateRaw = "start_date"
        case endDateRaw = "end_date"
        case coverImage = "cover_image"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // MARK: - Memberwise Initializer

    init(
        id: String,
        name: String,
        ownerId: String,
        startDate: Date,
        endDate: Date,
        coverImage: String? = nil,
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.name = name
        self.ownerId = ownerId
        self.startDateRaw = Self.formatDate(startDate)
        self.endDateRaw = Self.formatDate(endDate)
        self.coverImage = coverImage
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Date Parsing

    /// Shared date formatter for "yyyy-MM-dd" strings.
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    /// Calendar anchored to UTC. Trip start/end dates are calendar days with no
    /// meaningful time component, stored as UTC-midnight instants (see parseDate/formatDate).
    /// Any arithmetic or display formatting on startDate/endDate MUST use this calendar
    /// (or a formatter with `.timeZone` set to UTC) instead of `Calendar.current` /
    /// a default-timezone DateFormatter, or the displayed day will shift by one for any
    /// user in a timezone other than UTC.
    static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// Creates a DateFormatter anchored to UTC for displaying trip date anchors.
    static func utcDateFormatter(format: String) -> DateFormatter {
        let f = DateFormatter()
        f.dateFormat = format
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }

    /// Parses a "yyyy-MM-dd" string into a Date.
    static func parseDate(_ string: String) -> Date? {
        dateFormatter.date(from: string)
    }

    /// Formats a Date into "yyyy-MM-dd" string.
    static func formatDate(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }
}
