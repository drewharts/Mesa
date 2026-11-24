//
//  FeaturedListConfig.swift
//  loc
//
//  Data-driven featured lists for the top of Explore. Add an entry to `FeaturedLists.all` to feature
//  another public list; no other code changes are needed.
//

import Foundation

/// One featured list and the copy its hero card shows.
struct FeaturedListConfig: Identifiable, Hashable {
    /// Lowercased `place_lists.id`.
    let listId: String
    let title: String
    let subtitle: String
    /// Shows the "Find a table" button and starts the availability flow from it (lists whose places are on Resy).
    let offersFindTable: Bool

    var id: String { listId }

    /// Creates a config, normalizing the id so it matches ids returned by the database.
    init(listId: String, title: String, subtitle: String, offersFindTable: Bool) {
        self.listId = listId.lowercased()
        self.title = title
        self.subtitle = subtitle
        self.offersFindTable = offersFindTable
    }
}

enum FeaturedLists {
    /// Featured lists in display order (top of Explore).
    static let all: [FeaturedListConfig] = [
        FeaturedListConfig(
            listId: "389894C6-3EE7-49D1-8D10-86DCAE238B7D",
            title: "Hardest Tables in NYC",
            subtitle: "Live availability at NYC's hardest reservations",
            offersFindTable: true
        )
    ]
}
