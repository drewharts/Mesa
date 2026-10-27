//
//  TripsListViewModel.swift
//  loc
//
//  ViewModel for the trips list screen
//  Single Responsibility: Fetch and manage the user's trips list
//

import Foundation

@MainActor
class TripsListViewModel: ObservableObject {
    // MARK: - Published State

    @Published private(set) var trips: [LightweightTrip] = []
    @Published private(set) var isLoading = false
    @Published var showCreateTrip = false
    @Published private(set) var error: String?

    /// Past-trips section expanded state; persists for the app session only.
    private static var sessionPastExpanded = false
    @Published var isPastExpanded: Bool = TripsListViewModel.sessionPastExpanded {
        didSet { Self.sessionPastExpanded = isPastExpanded }
    }

    /// Ongoing first, then upcoming soonest-first; undated trips count as upcoming (at the end).
    var currentTrips: [LightweightTrip] {
        let split = TripTimeline.split(trips)
        return split.ongoing + split.upcoming
    }

    /// Past trips, most recent end date first.
    var pastTrips: [LightweightTrip] { TripTimeline.split(trips).past }

    func togglePastExpanded() {
        isPastExpanded.toggle()
        if isPastExpanded {
            AnalyticsService.track(.pastTripsExpanded, ["past_count": pastTrips.count])
        }
    }

    // MARK: - Dependencies

    private let tripService = ServiceContainer.shared.tripService

    // MARK: - Load Trips

    /// Fetches all trips owned by or shared with the given user.
    func loadTrips(userId: String) async {
        // Show last-known trips instantly, refresh in the background
        if trips.isEmpty, let cached = TripDataCache.shared.trips(forUser: userId) {
            trips = cached
        }
        isLoading = true
        error = nil

        do {
            let fresh = try await tripService.fetchUserTrips(userId: userId)
            trips = fresh
            TripDataCache.shared.storeTrips(fresh, forUser: userId)
        } catch is CancellationError {
            // Expected when SwiftUI cancels the task (view disappear, refresh restart)
            isLoading = false
            return
        } catch let urlError as URLError where urlError.code == .cancelled {
            // Expected when the underlying URLSession request is cancelled
            isLoading = false
            return
        } catch {
            self.error = error.localizedDescription
            print("[TripsListVM] Failed to load trips: \(error)")
        }

        isLoading = false
    }

    /// Deletes a trip and removes it from the local list.
    func deleteTrip(tripId: String) async {
        do {
            try await tripService.deleteTrip(tripId: tripId)
            trips.removeAll { $0.tripId == tripId }
            TripDataCache.shared.removeTrip(tripId)
        } catch {
            self.error = error.localizedDescription
            print("[TripsListVM] Failed to delete trip: \(error)")
        }
    }
}

/// Classifies trips as ongoing / upcoming / past against the user's local "today".
enum TripTimeline {
    struct Split {
        var ongoing: [LightweightTrip] = []
        var upcoming: [LightweightTrip] = []
        var past: [LightweightTrip] = []
    }

    /// Today's local calendar day expressed as a UTC-midnight anchor, matching how trip dates are stored.
    static func todayAnchor(now: Date = Date(), calendar: Calendar = .current) -> Date {
        let c = calendar.dateComponents([.year, .month, .day], from: now)
        return Trip.utcCalendar.date(from: c) ?? now
    }

    static func split(_ trips: [LightweightTrip], today: Date = todayAnchor()) -> Split {
        var result = Split()
        for trip in trips {
            let start = trip.parsedStartDate
            let end = trip.parsedEndDate ?? start
            if let end, end < today {
                result.past.append(trip)
            } else if let start, start <= today {
                result.ongoing.append(trip)
            } else {
                result.upcoming.append(trip)
            }
        }
        result.ongoing.sort { ($0.parsedEndDate ?? .distantFuture) < ($1.parsedEndDate ?? .distantFuture) }
        result.upcoming.sort { ($0.parsedStartDate ?? .distantFuture) < ($1.parsedStartDate ?? .distantFuture) }
        result.past.sort { ($0.parsedEndDate ?? $0.startDate) > ($1.parsedEndDate ?? $1.startDate) }
        return result
    }
}
