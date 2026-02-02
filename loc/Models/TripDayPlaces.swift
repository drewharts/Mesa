//
//  TripDayPlaces.swift
//  loc
//
//  Model representing places grouped by day for UI display.
//

import Foundation

/// Represents a single day in a trip with its assigned places.
struct TripDayPlaces: Identifiable {
    let date: Date
    var places: [TripPlaceItem]

    var id: Date { date }

    /// Returns the day number (1-indexed) for display.
    func dayNumber(from startDate: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: startDate, to: date)
        return (components.day ?? 0) + 1
    }

    /// Returns a formatted date string for display.
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    /// Returns a short formatted date string.
    var shortFormattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

/// Represents a place item within a trip day, combining TripPlace with place details.
struct TripPlaceItem: Identifiable {
    let tripPlace: TripPlace
    let place: LightweightPlace?

    var id: UUID { tripPlace.id }
    var placeId: String { tripPlace.placeId }
    var sortOrder: Int { tripPlace.sortOrder }
    var notes: String? { tripPlace.notes }

    /// Returns the place name or a placeholder.
    var placeName: String {
        place?.name ?? "Loading..."
    }

    /// Returns the place address or empty string.
    var placeAddress: String {
        place?.address ?? ""
    }
}
