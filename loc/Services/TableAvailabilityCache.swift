//
//  TableAvailabilityCache.swift
//  loc
//
//  Short-lived in-memory cache of finished table searches, so repeating the same search shows its results
//  instantly (the caller then refreshes them). Entries expire after five minutes.
//

import Foundation

/// What identifies a search: the list, the party, the day, the window and the places covered.
struct TableSearchKey: Hashable {
    let listId: String
    let request: TableSearchRequestKey
    /// Fingerprint of the place ids covered.
    let scope: String

    /// Builds the key for a list, a request (without place ids) and the places it covers.
    init(listId: String, request: TableAvailabilityRequest, scope: TableSearchScope) {
        self.listId = listId
        self.request = TableSearchRequestKey(partySize: request.partySize, date: request.date,
                                             timeStart: request.timeStart, timeEnd: request.timeEnd)
        self.scope = scope.placeIds.joined(separator: ",")
    }
}

/// The request fields that define a search.
struct TableSearchRequestKey: Hashable {
    let partySize: Int
    let date: String
    let timeStart: String
    let timeEnd: String
}

/// The final outcome of a finished search.
struct CachedTableSearch: Equatable {
    let places: [PlaceTableAvailability]
    let checked: Int
    let total: Int
    let providerName: String
}

final class TableAvailabilityCache {
    static let shared = TableAvailabilityCache()
    static let timeToLive: TimeInterval = 5 * 60

    private let lock = NSLock()
    private var entries: [TableSearchKey: (storedAt: Date, value: CachedTableSearch)] = [:]
    private let now: () -> Date

    /// Creates a cache; `now` is injectable for tests.
    init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    /// Remembers a finished search.
    func store(_ value: CachedTableSearch, for key: TableSearchKey) {
        lock.lock()
        defer { lock.unlock() }
        entries[key] = (now(), value)
    }

    /// The results of the same search run within the last five minutes; nil when none or expired.
    func value(for key: TableSearchKey) -> CachedTableSearch? {
        lock.lock()
        defer { lock.unlock() }
        guard let entry = entries[key] else { return nil }
        if now().timeIntervalSince(entry.storedAt) > Self.timeToLive {
            entries[key] = nil
            return nil
        }
        return entry.value
    }

    /// Forgets everything (tests).
    func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        entries.removeAll()
    }
}
