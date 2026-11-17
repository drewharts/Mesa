//
//  SearchMode.swift
//  loc
//
//  Which kind of result the search page looks for, and which backends a query should hit.
//

import Foundation

/// The Places | People toggle on the search page.
enum SearchMode: String, CaseIterable, Identifiable {
    case places
    case people

    var id: String { rawValue }

    /// Label shown on the segmented control.
    var title: String {
        switch self {
        case .places: return "Places"
        case .people: return "People"
        }
    }

    /// Placeholder text for the search field in this mode.
    var placeholder: String {
        switch self {
        case .places: return "Search places"
        case .people: return "Search people"
        }
    }
}

/// Which searches a query triggers for a mode. People mode never calls Google Places, and
/// Places mode never calls user search.
struct SearchPlan: Equatable {
    let searchesPlaces: Bool
    let searchesUsers: Bool
    let searchesKeywords: Bool
    let searchesAI: Bool

    /// Minimum query length before any search runs.
    static let minimumQueryLength = 2

    /// Query length above which Places mode also asks for AI suggestions.
    static let aiQueryLengthThreshold = 15

    /// Returns the searches to run for a query in the given mode.
    static func make(mode: SearchMode, query: String) -> SearchPlan {
        guard query.count >= minimumQueryLength else {
            return SearchPlan(searchesPlaces: false, searchesUsers: false, searchesKeywords: false, searchesAI: false)
        }
        switch mode {
        case .places:
            return SearchPlan(
                searchesPlaces: true,
                searchesUsers: false,
                searchesKeywords: true,
                searchesAI: query.count > aiQueryLengthThreshold
            )
        case .people:
            return SearchPlan(searchesPlaces: false, searchesUsers: true, searchesKeywords: false, searchesAI: false)
        }
    }
}
