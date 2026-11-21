//
//  TableAvailability.swift
//  loc
//
//  Request and response models for POST /lists/<list_id>/availability ("Find a table").
//  Decoding is lenient: missing counts default to zero and unknown statuses never fail the whole response.
//

import Foundation

// MARK: - Request

/// Body of the availability request; `date` is "YYYY-MM-DD" and the times are "HH:MM" (24-hour).
struct TableAvailabilityRequest: Encodable, Equatable {
    let partySize: Int
    let date: String
    let timeStart: String
    let timeEnd: String
    /// Restricts the check to these places (one chunk of a streamed search); nil checks the whole list.
    var placeIds: [String]? = nil

    enum CodingKeys: String, CodingKey {
        case partySize = "party_size"
        case date
        case timeStart = "time_start"
        case timeEnd = "time_end"
        case placeIds = "place_ids"
    }

    /// The same search limited to one chunk of places.
    func restricted(to ids: [String]) -> TableAvailabilityRequest {
        var copy = self
        copy.placeIds = ids
        return copy
    }

    /// Builds a request from a party size, a day and a time window, formatting the day in the given calendar.
    static func make(partySize: Int, date: Date, window: TableSearchWindow, calendar: Calendar = .current) -> TableAvailabilityRequest {
        TableAvailabilityRequest(
            partySize: partySize,
            date: TableTimeFormat.dateString(date, calendar: calendar),
            timeStart: TableTimeFormat.clockString(minutes: window.startMinutes),
            timeEnd: TableTimeFormat.clockString(minutes: window.endMinutes)
        )
    }
}

// MARK: - Response

/// One bookable time offered by a place.
struct TableSlot: Decodable, Equatable, Identifiable {
    /// "HH:MM" (24-hour).
    let time: String
    /// Seating type such as "Dining Room"; nil when the provider gives none.
    let type: String?

    var id: String { time + "|" + (type ?? "") }

    /// Minutes after midnight for sorting and display; nil when `time` is malformed.
    var minutes: Int? { TableTimeFormat.minutes(fromClock: time) }
}

/// Whether a place could be checked and had tables.
enum TableAvailabilityStatus: Equatable {
    case available
    case noTables
    case error
    case unknown
}

extension TableAvailabilityStatus: Decodable {
    /// Decodes the raw string, mapping anything unrecognized to `.unknown`.
    init(from decoder: Decoder) throws {
        let raw = (try? decoder.singleValueContainer().decode(String.self)) ?? ""
        switch raw.lowercased() {
        case "available": self = .available
        case "none": self = .noTables
        case "error": self = .error
        default: self = .unknown
        }
    }
}

/// Availability for one place of the list.
struct PlaceTableAvailability: Decodable, Equatable, Identifiable {
    let placeId: String
    let provider: String?
    let slots: [TableSlot]
    let bookingURL: String?
    let status: TableAvailabilityStatus

    var id: String { placeId.lowercased() }

    enum CodingKeys: String, CodingKey {
        case placeId = "place_id"
        case provider
        case slots
        case bookingURL = "booking_url"
        case status
    }

    /// Memberwise initializer (used by tests and previews).
    init(placeId: String, provider: String? = nil, slots: [TableSlot] = [], bookingURL: String? = nil, status: TableAvailabilityStatus) {
        self.placeId = placeId
        self.provider = provider
        self.slots = slots
        self.bookingURL = bookingURL
        self.status = status
    }

    /// Decodes a place, defaulting missing slots to none and a missing status to `.unknown`.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        placeId = try container.decode(String.self, forKey: .placeId)
        provider = try container.decodeIfPresent(String.self, forKey: .provider)
        slots = try container.decodeIfPresent([TableSlot].self, forKey: .slots) ?? []
        bookingURL = try container.decodeIfPresent(String.self, forKey: .bookingURL)
        status = try container.decodeIfPresent(TableAvailabilityStatus.self, forKey: .status) ?? .unknown
    }

    /// True when the place is bookable: it reported availability and has at least one slot.
    var hasTables: Bool { status == .available && !slots.isEmpty }

    /// Slots in time order (malformed times last).
    var sortedSlots: [TableSlot] {
        slots.sorted { ($0.minutes ?? Int.max) < ($1.minutes ?? Int.max) }
    }

    /// The booking link when it is a usable http(s) URL.
    var bookingDestination: URL? {
        ReservationLink(provider: provider, url: bookingURL).destinationURL
    }
}

/// Body of the availability response.
struct TableAvailabilityResponse: Decodable, Equatable {
    let checked: Int
    let places: [PlaceTableAvailability]
    let unsupportedCount: Int

    enum CodingKeys: String, CodingKey {
        case checked
        case places
        case unsupportedCount = "unsupported_count"
    }

    /// Memberwise initializer (used by tests and previews).
    init(checked: Int, places: [PlaceTableAvailability], unsupportedCount: Int = 0) {
        self.checked = checked
        self.places = places
        self.unsupportedCount = unsupportedCount
    }

    /// Decodes the response, defaulting missing counts and places to zero/empty.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        places = try container.decodeIfPresent([PlaceTableAvailability].self, forKey: .places) ?? []
        checked = try container.decodeIfPresent(Int.self, forKey: .checked) ?? places.count
        unsupportedCount = try container.decodeIfPresent(Int.self, forKey: .unsupportedCount) ?? 0
    }

    /// Places that have bookable tables.
    var placesWithTables: [PlaceTableAvailability] { places.filter(\.hasTables) }

    /// True when places were checked but every one of them failed, so "no tables" would be misleading.
    var allChecksFailed: Bool {
        !places.isEmpty && places.allSatisfy { $0.status == .error }
    }

    /// Display name of the booking provider ("Resy" when the response does not say).
    var providerName: String {
        let named = places.compactMap { ReservationLink.providerDisplayName($0.provider) }.first
        return named ?? "Resy"
    }
}
