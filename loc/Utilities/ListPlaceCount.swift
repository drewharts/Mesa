//
//  ListPlaceCount.swift
//  loc
//
//  Shared list-id normalization and place-count display so a stale metadata
//  snapshot can never show fewer places than the list actually has on screen.
//

import Foundation

enum ListPlaceCount {
    /// Lowercases UUID list ids so dictionary keys match regardless of Postgres vs Swift casing.
    static func normalizedId(_ id: String) -> String {
        UUID(uuidString: id)?.uuidString.lowercased() ?? id.lowercased()
    }

    /// Returns the number of places that should be shown for a list.
    /// Prefers a known metadata/cache total when more pages may still be loading,
    /// but never reports fewer places than are already loaded.
    static func displayed(cached: Int?, metadata: Int, loaded: Int) -> Int {
        max(cached ?? metadata, loaded, 0)
    }
}
