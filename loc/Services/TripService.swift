//
//  TripService.swift
//  loc
//
//  Service responsible for ALL trip CRUD operations
//  Single Responsibility: Trip data access and persistence
//

import Foundation

/// Service for managing trips (fetch, create, update, delete, day places)
@MainActor
class TripService {
    // MARK: - Singleton
    static let shared = TripService()

    // MARK: - Dependencies
    private let supabase = SupabaseManager.shared

    private init() {}

    // MARK: - Fetch Trips

    /// Fetches all trips owned by or shared with the given user.
    func fetchUserTrips(userId: String) async throws -> [LightweightTrip] {
        let params = UserIdParams(p_user_id: userId)

        let trips: [LightweightTrip] = try await supabase.client
            .rpc("get_user_trips", params: params)
            .execute()
            .value

        return trips
    }

    // MARK: - Create Trip

    /// Creates a new trip and returns the full Trip model.
    func createTrip(
        name: String,
        ownerId: String,
        startDate: Date,
        endDate: Date
    ) async throws -> Trip {
        let tripId = UUID().uuidString

        let record = NewTripRecord(
            id: tripId,
            name: name,
            owner_id: ownerId,
            start_date: Self.dateToString(startDate),
            end_date: Self.dateToString(endDate)
        )

        let trip: Trip = try await supabase.client
            .from("trips")
            .insert(record)
            .select()
            .single()
            .execute()
            .value

        return trip
    }

    // MARK: - Update Trip

    /// Updates trip metadata (name, dates).
    func updateTrip(
        tripId: String,
        name: String?,
        startDate: Date?,
        endDate: Date?
    ) async throws {
        var updates: [String: String] = [:]
        if let name = name { updates["name"] = name }
        if let startDate = startDate { updates["start_date"] = Self.dateToString(startDate) }
        if let endDate = endDate { updates["end_date"] = Self.dateToString(endDate) }

        guard !updates.isEmpty else { return }

        try await supabase.client
            .from("trips")
            .update(updates)
            .eq("id", value: tripId)
            .execute()
    }

    // MARK: - Delete Trip

    /// Deletes a trip (cascades to collaborators and day_places).
    func deleteTrip(tripId: String) async throws {
        try await supabase.client
            .from("trips")
            .delete()
            .eq("id", value: tripId)
            .execute()
    }

    // MARK: - Fetch Trip with Places

    /// Fetches a trip and all its day places with joined place/user info.
    func fetchTripWithPlaces(tripId: String) async throws -> (trip: Trip, dayPlaces: [TripDayPlace]) {
        let params = TripIdParams(p_trip_id: tripId)

        let rows: [TripWithPlaceRow] = try await supabase.client
            .rpc("get_trip_with_places", params: params)
            .execute()
            .value

        guard let firstRow = rows.first else {
            throw TripServiceError.tripNotFound
        }

        let trip = Trip(
            id: firstRow.tripId,
            name: firstRow.tripName,
            ownerId: firstRow.ownerId,
            startDate: Trip.parseDate(firstRow.startDate) ?? Date(),
            endDate: Trip.parseDate(firstRow.endDate) ?? Date(),
            coverImage: firstRow.coverImage
        )

        // Filter out rows with no day_place_id (trip has no places yet)
        let dayPlaces: [TripDayPlace] = rows.compactMap { row in
            guard let dayPlaceId = row.dayPlaceId,
                  let placeId = row.placeId else { return nil }

            return TripDayPlace(
                id: dayPlaceId,
                tripId: row.tripId,
                placeId: placeId,
                dayIndex: row.dayIndex ?? 0,
                sortOrder: row.sortOrder ?? 0,
                addedBy: row.addedBy,
                note: row.note,
                placeName: row.placeName,
                placeAddress: row.placeAddress,
                placeLatitude: row.placeLatitude,
                placeLongitude: row.placeLongitude,
                placePhoto: row.placePhoto,
                addedByName: row.addedByName,
                addedByPhotoUrl: row.addedByPhotoUrl,
                contentUrl: row.contentUrl,
                placeType: row.placeType
            )
        }

        return (trip, dayPlaces)
    }

    // MARK: - Day Place Operations

    /// Adds a place to a specific day of a trip.
    func addPlaceToDay(
        tripId: String,
        placeId: String,
        dayIndex: Int,
        addedBy: String
    ) async throws {
        // Get current max sort_order for this day
        let existing: [SortOrderResult] = try await supabase.client
            .from("trip_day_places")
            .select("sort_order")
            .eq("trip_id", value: tripId)
            .eq("day_index", value: dayIndex)
            .order("sort_order", ascending: false)
            .limit(1)
            .execute()
            .value

        let nextSortOrder = (existing.first?.sortOrder ?? -1) + 1

        let record = NewDayPlaceRecord(
            id: UUID().uuidString,
            trip_id: tripId,
            place_id: placeId,
            day_index: dayIndex,
            sort_order: nextSortOrder,
            added_by: addedBy
        )

        try await supabase.client
            .from("trip_day_places")
            .insert(record)
            .execute()
    }

    /// Removes a place entry from a trip day.
    func removePlaceFromDay(entryId: String) async throws {
        try await supabase.client
            .from("trip_day_places")
            .delete()
            .eq("id", value: entryId)
            .execute()
    }

    /// Moves a trip day place entry to a different day, appending at the end.
    func movePlaceToDifferentDay(entryId: String, newDayIndex: Int, tripId: String) async throws {
        // Get current max sort_order for the target day
        let existing: [SortOrderResult] = try await supabase.client
            .from("trip_day_places")
            .select("sort_order")
            .eq("trip_id", value: tripId)
            .eq("day_index", value: newDayIndex)
            .order("sort_order", ascending: false)
            .limit(1)
            .execute()
            .value

        let nextSortOrder = (existing.first?.sortOrder ?? -1) + 1

        let update = MoveDayUpdate(day_index: newDayIndex, sort_order: nextSortOrder)
        try await supabase.client
            .from("trip_day_places")
            .update(update)
            .eq("id", value: entryId)
            .execute()
    }

    /// Atomically reorders places within a day via RPC.
    func reorderDayPlaces(
        tripId: String,
        dayIndex: Int,
        placeIds: [String]
    ) async throws {
        let params = ReorderParams(
            p_trip_id: tripId,
            p_day_index: dayIndex,
            p_place_ids: placeIds
        )

        try await supabase.client
            .rpc("reorder_trip_day_places", params: params)
            .execute()
    }

    // MARK: - Ideas (Unassigned Places)

    /// Adds a place to a trip as an unassigned Idea (dayIndex = -1).
    func addPlaceAsIdea(tripId: String, placeId: String, addedBy: String) async throws {
        try await addPlaceToDay(
            tripId: tripId,
            placeId: placeId,
            dayIndex: TripDayPlace.ideasDayIndex,
            addedBy: addedBy
        )
    }

    /// Removes a place from a trip by matching trip_id and place_id.
    func removePlaceFromTrip(tripId: String, placeId: String) async throws {
        try await supabase.client
            .from("trip_day_places")
            .delete()
            .eq("trip_id", value: tripId)
            .eq("place_id", value: placeId)
            .execute()
    }

    /// Batch-checks which of the given trips contain a specific place.
    func fetchPlaceTripMembership(placeId: String, tripIds: [String]) async throws -> [String: Bool] {
        guard !tripIds.isEmpty else { return [:] }

        let rows: [TripPlaceMembershipRow] = try await supabase.client
            .from("trip_day_places")
            .select("trip_id")
            .eq("place_id", value: placeId)
            .in("trip_id", values: tripIds)
            .execute()
            .value

        let memberTripIds = Set(rows.map(\.tripId))
        var result: [String: Bool] = [:]
        for tripId in tripIds {
            result[tripId] = memberTripIds.contains(tripId)
        }
        return result
    }

    // MARK: - Helpers

    /// Formats a Date to yyyy-MM-dd string for Supabase date columns.
    private static func dateToString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }
}

// MARK: - Errors

enum TripServiceError: LocalizedError {
    case tripNotFound

    var errorDescription: String? {
        switch self {
        case .tripNotFound: return "Trip not found"
        }
    }
}

// MARK: - Private DTOs

private extension TripService {
    struct UserIdParams: Encodable {
        let p_user_id: String
    }

    struct TripIdParams: Encodable {
        let p_trip_id: String
    }

    struct NewTripRecord: Encodable {
        let id: String
        let name: String
        let owner_id: String
        let start_date: String
        let end_date: String
    }

    struct NewDayPlaceRecord: Encodable {
        let id: String
        let trip_id: String
        let place_id: String
        let day_index: Int
        let sort_order: Int
        let added_by: String
    }

    struct MoveDayUpdate: Encodable {
        let day_index: Int
        let sort_order: Int
    }

    struct SortOrderResult: Decodable {
        let sortOrder: Int

        enum CodingKeys: String, CodingKey {
            case sortOrder = "sort_order"
        }
    }

    struct ReorderParams: Encodable {
        let p_trip_id: String
        let p_day_index: Int
        let p_place_ids: [String]
    }

    struct TripPlaceMembershipRow: Decodable {
        let tripId: String

        enum CodingKeys: String, CodingKey {
            case tripId = "trip_id"
        }
    }

    /// Intermediate row type for the get_trip_with_places RPC response.
    struct TripWithPlaceRow: Decodable {
        let tripId: String
        let tripName: String
        let ownerId: String
        let startDate: String
        let endDate: String
        let coverImage: String?
        let dayPlaceId: String?
        let placeId: String?
        let dayIndex: Int?
        let sortOrder: Int?
        let addedBy: String?
        let note: String?
        let placeName: String?
        let placeAddress: String?
        let placeLatitude: Double?
        let placeLongitude: Double?
        let placePhoto: String?
        let addedByName: String?
        let addedByPhotoUrl: String?
        let externalPlaceId: String?
        let contentUrl: String?
        let placeType: String?

        enum CodingKeys: String, CodingKey {
            case tripId = "trip_id"
            case tripName = "trip_name"
            case ownerId = "owner_id"
            case startDate = "start_date"
            case endDate = "end_date"
            case coverImage = "cover_image"
            case dayPlaceId = "day_place_id"
            case placeId = "place_id"
            case dayIndex = "day_index"
            case sortOrder = "sort_order"
            case addedBy = "added_by"
            case note
            case placeName = "place_name"
            case placeAddress = "place_address"
            case placeLatitude = "place_latitude"
            case placeLongitude = "place_longitude"
            case placePhoto = "place_photo"
            case addedByName = "added_by_name"
            case addedByPhotoUrl = "added_by_photo_url"
            case externalPlaceId = "external_place_id"
            case contentUrl = "tiktok_url"
            case placeType = "place_type"
        }
    }
}
