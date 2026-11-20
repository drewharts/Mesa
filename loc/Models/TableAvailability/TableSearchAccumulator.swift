//
//  TableSearchAccumulator.swift
//  loc
//
//  Pure state of a streamed "Find a table" search: folds in chunk responses as they arrive, tracks progress,
//  and produces the places to display (fresh results, plus not-yet-refreshed cached ones while refreshing).
//

import Foundation

struct TableSearchAccumulator {
    /// Places to check in total.
    let total: Int
    /// Requests that will be made.
    let chunkCount: Int
    /// Cached places still shown until their chunk is refreshed.
    private let stale: [PlaceTableAvailability]

    private(set) var fresh: [PlaceTableAvailability] = []
    private(set) var processedPlaces = 0
    private(set) var processedChunks = 0
    private(set) var failedChunks = 0
    private(set) var checkedOnProvider = 0
    private(set) var providerName: String?
    private var processedIds = Set<String>()

    /// Starts a search over `total` places in `chunkCount` requests, optionally seeded with cached places.
    init(total: Int, chunkCount: Int, stale: [PlaceTableAvailability] = []) {
        self.total = total
        self.chunkCount = chunkCount
        self.stale = stale
    }

    /// Folds in a chunk's response (de-duplicated against earlier chunks); its tables land soonest-first.
    mutating func applySuccess(chunk: [String], response: TableAvailabilityResponse) {
        fresh = TableSearchPlanner.merge(fresh, with: TableSearchPlanner.orderedBySoonest(response.places))
        processedIds.formUnion(chunk.map { $0.lowercased() })
        processedIds.formUnion(response.places.map(\.id))
        checkedOnProvider += response.checked
        if providerName == nil, !response.places.isEmpty { providerName = response.providerName }
        finish(chunk: chunk)
    }

    /// Records a chunk that could not be checked; the rest of the search carries on.
    mutating func applyFailure(chunk: [String]) {
        failedChunks += 1
        finish(chunk: chunk)
    }

    private mutating func finish(chunk: [String]) {
        processedChunks += 1
        processedPlaces = min(processedPlaces + chunk.count, total)
    }

    /// True once every chunk has answered or failed.
    var isComplete: Bool { processedChunks >= chunkCount }

    /// True when nothing could be checked at all (every chunk failed and there is nothing cached to show).
    var allFailed: Bool { chunkCount > 0 && failedChunks == chunkCount && stale.isEmpty }

    /// Places to show now: fresh results plus cached ones whose chunk has not been refreshed yet.
    var displayed: [PlaceTableAvailability] {
        fresh + stale.filter { !processedIds.contains($0.id) }
    }

    /// Displayed places that have bookable tables.
    var withTables: [PlaceTableAvailability] { displayed.filter(\.hasTables) }

    /// True when places were checked but every one of them failed, so "no tables" would be misleading.
    var everyPlaceErrored: Bool {
        stale.isEmpty && !fresh.isEmpty && fresh.allSatisfy { $0.status == .error }
    }

    /// Fraction of places processed, 0...1.
    var fraction: Double { total == 0 ? 1 : Double(processedPlaces) / Double(total) }
}
