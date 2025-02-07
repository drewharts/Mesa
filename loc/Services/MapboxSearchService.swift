//
//  MapboxSearchService.swift
//  loc
//
//  Created by Andrew Hartsfield II on 2/6/25.
//


import Foundation
import MapboxSearch

class MapboxSearchService: SearchEngineDelegate {
    private let searchEngine = SearchEngine()
    private var onResultsUpdated: (([SearchSuggestion]) -> Void)?
    private var onResultResolved: ((SearchResult) -> Void)?
    private var onError: ((String) -> Void)?
    
    init() {
        searchEngine.delegate = self
    }

    // Perform search
    func searchPlaces(query: String, onResultsUpdated: @escaping ([SearchSuggestion]) -> Void, onError: @escaping (String) -> Void) {
        guard !query.isEmpty else {
            onResultsUpdated([]) // Clear results if empty query
            return
        }
        
        self.onResultsUpdated = onResultsUpdated
        self.onError = onError
        searchEngine.query = query
    }

    // Select a suggestion
    func selectSuggestion(_ suggestion: SearchSuggestion, onResultResolved: @escaping (SearchResult) -> Void) {
        self.onResultResolved = onResultResolved
        searchEngine.select(suggestion: suggestion)
    }

    // MARK: - SearchEngineDelegate Methods
    func suggestionsUpdated(suggestions: [any SearchSuggestion], searchEngine: SearchEngine) {
        onResultsUpdated?(suggestions)
    }

    func resultResolved(result: any SearchResult, searchEngine: SearchEngine) {
        onResultResolved?(result)
    }

    func searchErrorHappened(searchError: SearchError, searchEngine: SearchEngine) {
        onError?(searchError.localizedDescription)
    }
}