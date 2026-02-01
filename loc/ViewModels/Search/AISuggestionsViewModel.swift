//
//  AISuggestionsViewModel.swift
//  loc
//
//  ViewModel for AI-powered place suggestions
//

import Foundation
import CoreLocation

/// ViewModel for managing AI-powered place suggestions
/// Single Responsibility: Handle AI search state and coordinate with PlaceSearchService
@MainActor
class AISuggestionsViewModel: ObservableObject {
    // MARK: - Published State

    @Published var suggestions: [DetailPlace] = []
    @Published var isLoading: Bool = false
    @Published var error: String?

    // MARK: - Private Properties

    private let searchService = PlaceSearchService()
    private var currentSearchTask: Task<Void, Never>?

    // MARK: - Public Methods

    /// Search for AI-powered place suggestions
    func search(query: String, latitude: Double, longitude: Double) {
        // Cancel any existing search task
        currentSearchTask?.cancel()

        isLoading = true
        error = nil

        currentSearchTask = Task {
            await performSearch(query: query, latitude: latitude, longitude: longitude)
        }
    }

    /// Clear all suggestions and reset state
    func clear() {
        currentSearchTask?.cancel()
        currentSearchTask = nil
        suggestions = []
        isLoading = false
        error = nil
    }

    // MARK: - Private Methods

    /// Perform the AI suggestions search
    private func performSearch(query: String, latitude: Double, longitude: Double) async {
        guard !Task.isCancelled else {
            print("🤖 [AISuggestionsViewModel] Search cancelled before starting")
            return
        }

        print("🤖 [AISuggestionsViewModel] Starting search for: '\(query)'")

        await withCheckedContinuation { continuation in
            searchService.searchAISuggestions(
                query: query,
                latitude: latitude,
                longitude: longitude,
                onResultsUpdated: { [weak self] results in
                    guard let self = self else {
                        continuation.resume()
                        return
                    }

                    print("🤖 [AISuggestionsViewModel] Received \(results.count) suggestions")
                    for (index, place) in results.prefix(3).enumerated() {
                        print("   \(index + 1). \(place.name) - \(place.aiSuggestionReason ?? "no reason")")
                    }

                    self.suggestions = results
                    self.isLoading = false
                    continuation.resume()
                },
                onError: { [weak self] errorMessage in
                    guard let self = self else {
                        continuation.resume()
                        return
                    }

                    print("🤖 [AISuggestionsViewModel] Error: \(errorMessage)")
                    self.error = errorMessage
                    self.isLoading = false
                    continuation.resume()
                }
            )
        }
    }
}
