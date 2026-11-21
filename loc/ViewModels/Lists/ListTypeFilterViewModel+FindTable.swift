//
//  ListTypeFilterViewModel+FindTable.swift
//  loc
//
//  Tells "Find a table" which places to check: the active chip or search, else the whole list.
//

import Foundation

extension ListTypeFilterViewModel {
    /// The places a table search should cover for the current chip/search selection, with its label ("Sushi").
    func findTableScope(loaded places: [LightweightPlace]) -> TableSearchScope {
        let scopeIds = display(for: places, filtersByType: true).scopeIds
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = hasSearchQuery ? query : selection
        var allIds = Set(places.map { $0.place_id.lowercased() })
        if let fullIndex { allIds.formUnion(fullIndex.tagsByPlaceId.keys.map { $0.lowercased() }) }
        return TableSearchPlanner.scope(scopeIds: scopeIds, label: label, allIds: allIds)
    }
}
