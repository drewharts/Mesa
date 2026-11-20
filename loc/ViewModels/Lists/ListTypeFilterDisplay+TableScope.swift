//
//  ListTypeFilterDisplay+TableScope.swift
//  loc
//
//  Narrows a list display to the places a "Find a table" search found tables at.
//

import Foundation

extension ListTypeFilterViewModel.Display {
    /// This display limited to places in `ids` (lowercased); tiles, load-more triggers and the map/header scope follow.
    func narrowed(toPlaceIds ids: Set<String>) -> ListTypeFilterViewModel.Display {
        let kept = tiles.filter { ids.contains($0.place_id.lowercased()) }
        return ListTypeFilterViewModel.Display(
            chips: chips,
            showsFilterRow: showsFilterRow,
            tiles: kept,
            loadMoreTriggerIds: loadMoreTriggerIds,
            scopeIds: scopeIds.map { $0.intersection(ids) } ?? ids
        )
    }
}
