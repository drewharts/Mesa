//
//  DamnlinesWaitViewModel.swift
//  loc
//
//  Lazily loads damnlines wait-time data for the place sheet without blocking it.
//

import Foundation

@MainActor
final class DamnlinesWaitViewModel: ObservableObject {
    @Published private(set) var info: DamnlinesWaitInfo?

    /// In-memory cache per place id; a nil value means "no wait data" (also cached).
    private static var cache: [String: DamnlinesWaitInfo?] = [:]
    private var loadedPlaceId: String?
    private let service: DamnlinesWaitService

    /// Creates a view model backed by the given service.
    init(service: DamnlinesWaitService = .shared) {
        self.service = service
    }

    /// Loads wait data for a place; stays nil for unmapped places and on any failure.
    func load(placeId: String) async {
        guard !placeId.isEmpty, placeId != loadedPlaceId else { return }
        loadedPlaceId = placeId
        info = nil
        guard DamnlinesPlaceMap.slug(forPlaceId: placeId) != nil else { return }
        if let cached = Self.cache[placeId] {
            info = cached
            return
        }
        let fetched = await service.waitInfo(forPlaceId: placeId)
        guard loadedPlaceId == placeId else { return }
        if fetched != nil { Self.cache[placeId] = .some(fetched) }
        info = fetched
    }
}
