//
//  TripDataCache.swift
//  loc
//
//  In-memory cache for trips so the trips list and trip detail open instantly
//  with the last-known data, then refresh in the background.
//

import Foundation

@MainActor
final class TripDataCache {
    static let shared = TripDataCache()
    private init() {}

    /// Last-fetched trips list per user.
    private var tripsByUser: [String: [LightweightTrip]] = [:]
    /// Lightweight trip summaries (from the list) keyed by trip ID, used to seed detail headers.
    private var summaries: [String: LightweightTrip] = [:]
    /// Last-fetched full trip detail keyed by trip ID.
    private var details: [String: (trip: Trip, dayPlaces: [Int: [TripDayPlace]])] = [:]
    /// Last-fetched place details keyed by place ID.
    private var places: [String: DetailPlace] = [:]

    // MARK: Trips list

    func trips(forUser userId: String) -> [LightweightTrip]? { tripsByUser[userId] }

    func storeTrips(_ trips: [LightweightTrip], forUser userId: String) {
        tripsByUser[userId] = trips
        for trip in trips { summaries[trip.tripId] = trip }
    }

    func summary(for tripId: String) -> LightweightTrip? { summaries[tripId] }

    // MARK: Trip detail

    func detail(for tripId: String) -> (trip: Trip, dayPlaces: [Int: [TripDayPlace]])? { details[tripId] }

    func storeDetail(trip: Trip, dayPlaces: [Int: [TripDayPlace]]) {
        details[trip.id] = (trip, dayPlaces)
    }

    func removeTrip(_ tripId: String) {
        details[tripId] = nil
        summaries[tripId] = nil
        for key in tripsByUser.keys { tripsByUser[key]?.removeAll { $0.tripId == tripId } }
    }

    // MARK: Places

    func place(for placeId: String) -> DetailPlace? { places[placeId] }

    func storePlace(_ place: DetailPlace, id placeId: String) {
        if places.count > 300 { places.removeAll() }
        places[placeId] = place
    }
}
