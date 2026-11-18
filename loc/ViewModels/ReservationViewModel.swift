//
//  ReservationViewModel.swift
//  loc
//
//  Lazily loads the reservation link for the place sheet without blocking it.
//

import Foundation

@MainActor
final class ReservationViewModel: ObservableObject {
    @Published private(set) var link: ReservationLink?

    /// In-memory cache per place id; a nil value means "no reservation link" (also cached).
    private static var cache: [String: ReservationLink?] = [:]
    private var loadedPlaceId: String?

    /// Loads the reservation link for a place if it is reservable; hides the button on any failure.
    func load(placeId: String, place: DetailPlace?) async {
        guard !placeId.isEmpty, placeId != loadedPlaceId else { return }
        loadedPlaceId = placeId
        link = nil
        guard let place, place.reservable == true || ReservationLink.isReservableCategory(place.categories) else { return }

        if let cached = Self.cache[placeId] {
            link = cached
            return
        }
        let fetched = try? await MesaBackendService.shared.fetchReservation(placeId: placeId)
        guard loadedPlaceId == placeId else { return }
        let usable = fetched?.destinationURL != nil ? fetched : nil
        Self.cache[placeId] = .some(usable)
        link = usable
    }

    /// Records the tap in analytics.
    func trackTap() {
        AnalyticsService.track(.reservationTapped, ["provider": link?.provider ?? "unknown"])
    }
}
