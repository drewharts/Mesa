//
//  TableSearchPlanner.swift
//  loc
//
//  Pure helpers for a streamed "Find a table" search: which places to check (the active chip or search
//  scope, else the whole list), how to split them into request chunks, and how to merge chunk responses.
//

import Foundation

/// What a table search covers: specific places (the active chip or search) or the whole list.
struct TableSearchScope: Equatable {
    /// Lowercased place ids to check, in a stable order.
    let placeIds: [String]
    /// The chip or search text that narrowed the scope ("Sushi"); nil when the whole list is searched.
    let label: String?

    var isEmpty: Bool { placeIds.isEmpty }
}

enum TableSearchPlanner {
    /// Places per request.
    static let chunkSize = 10
    /// Requests in flight at once.
    static let maxConcurrentChunks = 3

    /// Chooses the places to check: the chip/search scope when one is active, else every place of the list
    /// (the whole-list index when known, otherwise the loaded places). Ids are lowercased, de-duplicated and sorted.
    static func scope(scopeIds: Set<String>?, label: String?, allIds: Set<String>) -> TableSearchScope {
        if let scopeIds {
            return TableSearchScope(placeIds: scopeIds.map { $0.lowercased() }.uniqueSorted(), label: label)
        }
        return TableSearchScope(placeIds: allIds.map { $0.lowercased() }.uniqueSorted(), label: nil)
    }

    /// Splits ids into consecutive chunks of at most `size`.
    static func chunks(_ ids: [String], size: Int = chunkSize) -> [[String]] {
        guard size > 0, !ids.isEmpty else { return [] }
        return stride(from: 0, to: ids.count, by: size).map { Array(ids[$0..<min($0 + size, ids.count)]) }
    }

    /// Merges a chunk's places into the accumulated ones, de-duplicating by place id. A duplicate only replaces
    /// the existing entry when that one could not be checked and the new one could. Order of first arrival is kept.
    static func merge(_ existing: [PlaceTableAvailability], with incoming: [PlaceTableAvailability]) -> [PlaceTableAvailability] {
        var merged = existing
        var indexById = Dictionary(uniqueKeysWithValues: existing.enumerated().map { ($1.id, $0) })
        for place in incoming {
            if let index = indexById[place.id] {
                if !isChecked(merged[index]) && isChecked(place) { merged[index] = place }
            } else {
                indexById[place.id] = merged.count
                merged.append(place)
            }
        }
        return merged
    }

    /// A chunk's tables ordered by their earliest slot, so each arriving batch lands soonest-first.
    static func orderedBySoonest(_ places: [PlaceTableAvailability]) -> [PlaceTableAvailability] {
        places.enumerated().sorted { lhs, rhs in
            let l = lhs.element.sortedSlots.first?.minutes ?? Int.max
            let r = rhs.element.sortedSlots.first?.minutes ?? Int.max
            return l != r ? l < r : lhs.offset < rhs.offset
        }.map(\.element)
    }

    /// True when the provider gave a real answer for the place (tables or none), not an error or unknown.
    private static func isChecked(_ place: PlaceTableAvailability) -> Bool {
        place.status == .available || place.status == .noTables
    }
}

private extension Array where Element == String {
    /// Sorted with duplicates removed.
    func uniqueSorted() -> [String] { Array(Set(self)).sorted() }
}
