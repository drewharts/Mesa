//
//  LightweightTrip.swift
//  loc
//
//  Lightweight trip model for list display with minimal data.
//

import Foundation

/// Lightweight trip representation for efficient list display.
struct LightweightTrip: Identifiable, Codable {
    let tripId: String
    let name: String
    let startDate: Date
    let endDate: Date
    let coverImage: String?
    let placeCount: Int
    let createdAt: Date?

    var id: String { tripId }

    enum CodingKeys: String, CodingKey {
        case tripId = "trip_id"
        case name
        case startDate = "start_date"
        case endDate = "end_date"
        case coverImage = "cover_image"
        case placeCount = "place_count"
        case createdAt = "created_at"
    }

    /// Creates a lightweight trip from a full Trip model.
    init(from trip: Trip, placeCount: Int) {
        self.tripId = trip.id.uuidString
        self.name = trip.name
        self.startDate = trip.startDate
        self.endDate = trip.endDate
        self.coverImage = trip.coverImage
        self.placeCount = placeCount
        self.createdAt = trip.createdAt
    }

    /// Creates a lightweight trip with explicit values.
    init(
        tripId: String,
        name: String,
        startDate: Date,
        endDate: Date,
        coverImage: String? = nil,
        placeCount: Int = 0,
        createdAt: Date? = nil
    ) {
        self.tripId = tripId
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.coverImage = coverImage
        self.placeCount = placeCount
        self.createdAt = createdAt
    }

    /// Returns the number of days in this trip.
    var numberOfDays: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: startDate, to: endDate)
        return (components.day ?? 0) + 1
    }

    /// Returns a formatted date range string.
    var formattedDateRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        let calendar = Calendar.current
        let startYear = calendar.component(.year, from: startDate)
        let endYear = calendar.component(.year, from: endDate)
        let currentYear = calendar.component(.year, from: Date())

        if startYear == endYear && startYear == currentYear {
            return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        } else if startYear == endYear {
            formatter.dateFormat = "MMM d, yyyy"
            return "\(formatter.string(from: startDate)) - \(DateFormatter.localizedString(from: endDate, dateStyle: .medium, timeStyle: .none))"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
            return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        }
    }
}
