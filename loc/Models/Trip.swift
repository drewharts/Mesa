//
//  Trip.swift
//  loc
//
//  Model representing a user's trip with date range and associated places.
//

import Foundation

/// Represents a trip created by a user with a date range.
struct Trip: Identifiable, Codable {
    let id: UUID
    let userId: String
    var name: String
    var startDate: Date
    var endDate: Date
    var coverImage: String?
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case startDate = "start_date"
        case endDate = "end_date"
        case coverImage = "cover_image"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// Creates a new trip with default values.
    init(
        id: UUID = UUID(),
        userId: String,
        name: String,
        startDate: Date,
        endDate: Date,
        coverImage: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.coverImage = coverImage
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Returns the number of days in this trip.
    var numberOfDays: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: startDate, to: endDate)
        return (components.day ?? 0) + 1 // +1 to include both start and end dates
    }

    /// Returns an array of all dates in this trip's range.
    var allDates: [Date] {
        var dates: [Date] = []
        var currentDate = startDate
        let calendar = Calendar.current

        while currentDate <= endDate {
            dates.append(currentDate)
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }

        return dates
    }
}
