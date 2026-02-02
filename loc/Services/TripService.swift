//
//  TripService.swift
//  loc
//
//  Service responsible for all trip-related operations.
//  Single source of truth for trip data access.
//

import Foundation

/// Service for managing trips (fetch, create, update, delete).
/// Owns all database operations related to trips.
@MainActor
class TripService {
    // MARK: - Singleton
    static let shared = TripService()

    // MARK: - Dependencies
    private let supabase = SupabaseManager.shared

    private init() {}

    // MARK: - Fetch Trips

    /// Fetches all trips for a user, ordered by start date descending.
    func fetchUserTrips(userId: String) async throws -> [LightweightTrip] {
        struct TripWithCount: Decodable {
            let id: String
            let user_id: String
            let name: String
            let start_date: String
            let end_date: String
            let cover_image: String?
            let created_at: String
            let place_count: Int?
        }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]

        let dateTimeFormatter = ISO8601DateFormatter()
        dateTimeFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Query trips with place count using a subquery
        let trips: [TripWithCount] = try await supabase.client
            .from("trips")
            .select("*, place_count:trip_places(count)")
            .eq("user_id", value: userId)
            .order("start_date", ascending: false)
            .execute()
            .value

        return trips.compactMap { record in
            guard let startDate = dateFormatter.date(from: record.start_date),
                  let endDate = dateFormatter.date(from: record.end_date) else {
                return nil
            }

            let createdAt = dateTimeFormatter.date(from: record.created_at) ?? Date()

            return LightweightTrip(
                tripId: record.id,
                name: record.name,
                startDate: startDate,
                endDate: endDate,
                coverImage: record.cover_image,
                placeCount: record.place_count ?? 0,
                createdAt: createdAt
            )
        }
    }

    /// Fetches a single trip by ID.
    func fetchTrip(tripId: String) async throws -> Trip? {
        struct TripRecord: Decodable {
            let id: String
            let user_id: String
            let name: String
            let start_date: String
            let end_date: String
            let cover_image: String?
            let created_at: String
            let updated_at: String
        }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]

        let dateTimeFormatter = ISO8601DateFormatter()
        dateTimeFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let record: TripRecord = try await supabase.client
            .from("trips")
            .select()
            .eq("id", value: tripId)
            .single()
            .execute()
            .value

        guard let tripUUID = UUID(uuidString: record.id),
              let startDate = dateFormatter.date(from: record.start_date),
              let endDate = dateFormatter.date(from: record.end_date) else {
            return nil
        }

        let createdAt = dateTimeFormatter.date(from: record.created_at) ?? Date()
        let updatedAt = dateTimeFormatter.date(from: record.updated_at) ?? Date()

        return Trip(
            id: tripUUID,
            userId: record.user_id,
            name: record.name,
            startDate: startDate,
            endDate: endDate,
            coverImage: record.cover_image,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    // MARK: - Fetch Trip Places

    /// Fetches all places for a trip grouped by day.
    func fetchTripPlacesByDay(tripId: String) async throws -> [TripDayPlaces] {
        struct TripPlaceRecord: Decodable {
            let id: String
            let trip_id: String
            let place_id: String
            let day_date: String
            let sort_order: Int
            let notes: String?
            let created_at: String
        }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]

        let dateTimeFormatter = ISO8601DateFormatter()
        dateTimeFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let records: [TripPlaceRecord] = try await supabase.client
            .from("trip_places")
            .select()
            .eq("trip_id", value: tripId)
            .order("day_date", ascending: true)
            .order("sort_order", ascending: true)
            .execute()
            .value

        // Group by day
        var dayPlacesDict: [Date: [TripPlaceItem]] = [:]

        for record in records {
            guard let recordUUID = UUID(uuidString: record.id),
                  let tripUUID = UUID(uuidString: record.trip_id),
                  let dayDate = dateFormatter.date(from: record.day_date) else {
                continue
            }

            let createdAt = dateTimeFormatter.date(from: record.created_at) ?? Date()

            let tripPlace = TripPlace(
                id: recordUUID,
                tripId: tripUUID,
                placeId: record.place_id,
                dayDate: dayDate,
                sortOrder: record.sort_order,
                notes: record.notes,
                createdAt: createdAt
            )

            let item = TripPlaceItem(tripPlace: tripPlace, place: nil)

            if dayPlacesDict[dayDate] != nil {
                dayPlacesDict[dayDate]?.append(item)
            } else {
                dayPlacesDict[dayDate] = [item]
            }
        }

        // Convert to array sorted by date
        return dayPlacesDict.keys.sorted().map { date in
            TripDayPlaces(date: date, places: dayPlacesDict[date] ?? [])
        }
    }

    /// Fetches place IDs for a trip.
    func fetchTripPlaceIds(tripId: String) async throws -> [String] {
        struct PlaceIdRecord: Decodable {
            let place_id: String
        }

        let records: [PlaceIdRecord] = try await supabase.client
            .from("trip_places")
            .select("place_id")
            .eq("trip_id", value: tripId)
            .execute()
            .value

        return records.map { $0.place_id }
    }

    // MARK: - Create Trip

    /// Creates a new trip for a user.
    func createTrip(
        userId: String,
        name: String,
        startDate: Date,
        endDate: Date,
        coverImage: String? = nil
    ) async throws -> Trip {
        struct NewTripRecord: Encodable {
            let id: String
            let user_id: String
            let name: String
            let start_date: String
            let end_date: String
            let cover_image: String?
        }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]

        let tripId = UUID()

        let newTrip = NewTripRecord(
            id: tripId.uuidString,
            user_id: userId,
            name: name,
            start_date: dateFormatter.string(from: startDate),
            end_date: dateFormatter.string(from: endDate),
            cover_image: coverImage
        )

        try await supabase.client
            .from("trips")
            .insert(newTrip)
            .execute()

        return Trip(
            id: tripId,
            userId: userId,
            name: name,
            startDate: startDate,
            endDate: endDate,
            coverImage: coverImage
        )
    }

    // MARK: - Update Trip

    /// Updates an existing trip's metadata.
    func updateTrip(
        tripId: String,
        name: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        coverImage: String? = nil
    ) async throws {
        var updates: [String: AnyEncodable] = [:]

        if let name = name {
            updates["name"] = AnyEncodable(name)
        }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]

        if let startDate = startDate {
            updates["start_date"] = AnyEncodable(dateFormatter.string(from: startDate))
        }

        if let endDate = endDate {
            updates["end_date"] = AnyEncodable(dateFormatter.string(from: endDate))
        }

        if let coverImage = coverImage {
            updates["cover_image"] = AnyEncodable(coverImage)
        }

        updates["updated_at"] = AnyEncodable(ISO8601DateFormatter().string(from: Date()))

        guard !updates.isEmpty else { return }

        try await supabase.client
            .from("trips")
            .update(updates)
            .eq("id", value: tripId)
            .execute()
    }

    // MARK: - Delete Trip

    /// Deletes a trip and all its associated places (cascades via FK).
    func deleteTrip(tripId: String) async throws {
        try await supabase.client
            .from("trips")
            .delete()
            .eq("id", value: tripId)
            .execute()
    }

    // MARK: - Add Place to Trip

    /// Adds a place to a specific day in a trip.
    func addPlaceToTrip(
        tripId: String,
        placeId: String,
        dayDate: Date,
        sortOrder: Int = 0,
        notes: String? = nil
    ) async throws -> TripPlace {
        struct NewTripPlaceRecord: Encodable {
            let id: String
            let trip_id: String
            let place_id: String
            let day_date: String
            let sort_order: Int
            let notes: String?
        }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]

        let tripPlaceId = UUID()

        let newRecord = NewTripPlaceRecord(
            id: tripPlaceId.uuidString,
            trip_id: tripId,
            place_id: placeId,
            day_date: dateFormatter.string(from: dayDate),
            sort_order: sortOrder,
            notes: notes
        )

        try await supabase.client
            .from("trip_places")
            .insert(newRecord)
            .execute()

        guard let tripUUID = UUID(uuidString: tripId) else {
            throw TripServiceError.invalidUUID
        }

        return TripPlace(
            id: tripPlaceId,
            tripId: tripUUID,
            placeId: placeId,
            dayDate: dayDate,
            sortOrder: sortOrder,
            notes: notes
        )
    }

    // MARK: - Remove Place from Trip

    /// Removes a place from a specific day in a trip.
    func removePlaceFromTrip(tripId: String, placeId: String, dayDate: Date) async throws {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]

        try await supabase.client
            .from("trip_places")
            .delete()
            .eq("trip_id", value: tripId)
            .eq("place_id", value: placeId)
            .eq("day_date", value: dateFormatter.string(from: dayDate))
            .execute()
    }

    /// Removes a place from all days in a trip.
    func removePlaceFromAllDays(tripId: String, placeId: String) async throws {
        try await supabase.client
            .from("trip_places")
            .delete()
            .eq("trip_id", value: tripId)
            .eq("place_id", value: placeId)
            .execute()
    }

    // MARK: - Move Place Between Days

    /// Moves a place from one day to another within a trip.
    func movePlaceToDay(
        tripId: String,
        placeId: String,
        fromDate: Date,
        toDate: Date,
        newSortOrder: Int
    ) async throws {
        struct MovePlaceUpdate: Encodable {
            let day_date: String
            let sort_order: Int
        }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]

        let update = MovePlaceUpdate(
            day_date: dateFormatter.string(from: toDate),
            sort_order: newSortOrder
        )

        try await supabase.client
            .from("trip_places")
            .update(update)
            .eq("trip_id", value: tripId)
            .eq("place_id", value: placeId)
            .eq("day_date", value: dateFormatter.string(from: fromDate))
            .execute()
    }

    // MARK: - Reorder Places in Day

    /// Reorders places within a day by updating their sort_order.
    func reorderPlacesInDay(
        tripId: String,
        dayDate: Date,
        placeIds: [String]
    ) async throws {
        struct SortOrderUpdate: Encodable {
            let sort_order: Int
        }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]
        let dayDateString = dateFormatter.string(from: dayDate)

        // Update each place's sort order
        for (index, placeId) in placeIds.enumerated() {
            try await supabase.client
                .from("trip_places")
                .update(SortOrderUpdate(sort_order: index))
                .eq("trip_id", value: tripId)
                .eq("place_id", value: placeId)
                .eq("day_date", value: dayDateString)
                .execute()
        }
    }

    // MARK: - Update Place Notes

    /// Updates notes for a specific place assignment.
    func updatePlaceNotes(tripPlaceId: String, notes: String?) async throws {
        struct NotesUpdate: Encodable {
            let notes: String?
        }

        try await supabase.client
            .from("trip_places")
            .update(NotesUpdate(notes: notes))
            .eq("id", value: tripPlaceId)
            .execute()
    }
}

// MARK: - Error Types

enum TripServiceError: Error {
    case invalidUUID
    case tripNotFound
    case placeNotFound
    case duplicatePlaceOnDay
}

// MARK: - Helper Types

/// Type-erased encodable wrapper for dynamic updates.
struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    init<T: Encodable>(_ value: T) {
        _encode = { encoder in
            try value.encode(to: encoder)
        }
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
