//
//  LightweightTrip.swift
//  loc
//
//  Lightweight trip model for list display (from RPC)
//

import Foundation

/// Lightweight trip representation returned by get_user_trips RPC.
/// Used for efficient list display without full model overhead.
struct LightweightTrip: Codable, Identifiable, Equatable {
    let tripId: String
    let name: String
    let coverImage: String?
    let ownerId: String?
    let ownerName: String?
    let placeCount: Int
    let collaboratorCount: Int?
    let collaboratorPhotos: [String]?
    let isShared: Bool?

    // Stored as strings for reliable Supabase date decoding
    private let startDateRaw: String
    private let endDateRaw: String

    var id: String { tripId }

    /// Parsed start date.
    var startDate: Date {
        Trip.parseDate(startDateRaw) ?? Date()
    }

    /// Parsed end date.
    var endDate: Date {
        Trip.parseDate(endDateRaw) ?? Date()
    }

    /// Returns the inclusive number of days in this trip.
    var numberOfDays: Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        return max(days + 1, 1)
    }

    /// Formatted date range string (e.g. "Jan 15 - Jan 20, 2026").
    var dateRangeString: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        let sameYear = calendar.component(.year, from: startDate) == calendar.component(.year, from: endDate)

        if sameYear {
            formatter.dateFormat = "MMM d"
            let start = formatter.string(from: startDate)
            formatter.dateFormat = "MMM d, yyyy"
            let end = formatter.string(from: endDate)
            return "\(start) - \(end)"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
            return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        }
    }

    enum CodingKeys: String, CodingKey {
        case tripId = "trip_id"
        case name
        case startDateRaw = "start_date"
        case endDateRaw = "end_date"
        case coverImage = "cover_image"
        case ownerId = "owner_id"
        case ownerName = "owner_name"
        case placeCount = "place_count"
        case collaboratorCount = "collaborator_count"
        case collaboratorPhotos = "collaborator_photos"
        case isShared = "is_shared"
    }
}
