//
//  ListTagSourceCache.swift
//  loc
//
//  Per-list memory of the whole-list tag index, so reopening a list shows every chip immediately
//  while a fresh copy is fetched in the background.
//

import Foundation

@MainActor
final class ListTagSourceCache {
    static let shared = ListTagSourceCache()

    private var indexes: [String: ListTagIndex] = [:]

    /// The cached whole-list tag index for a list, if one was stored.
    func index(for listId: String) -> ListTagIndex? {
        indexes[listId.lowercased()]
    }

    /// Stores the whole-list tag index for a list.
    func store(_ index: ListTagIndex, for listId: String) {
        indexes[listId.lowercased()] = index
    }
}
