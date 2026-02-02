//
//  TripSearchOverlayViewModel.swift
//  loc
//
//  ViewModel for trip place search functionality.
//

import SwiftUI

/// Manages search state and operations for adding places to trips.
@MainActor
class TripSearchOverlayViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var searchText: String = ""
    @Published var searchResults: [LightweightPlace] = []
    @Published var isSearching: Bool = false

    // MARK: - Dependencies

    private let placeService = SupabasePlaceService.shared

    // MARK: - Public Methods

    /// Performs a place search with the current search text.
    func performSearch() {
        guard searchText.count >= 2 else {
            searchResults = []
            return
        }

        isSearching = true

        Task {
            do {
                let results = try await placeService.searchPlaces(query: searchText, limit: 20)
                searchResults = results
                isSearching = false
            } catch {
                print("❌ [TripSearchOverlayViewModel] Search failed: \(error)")
                searchResults = []
                isSearching = false
            }
        }
    }

    /// Clears the search text and results.
    func clearSearch() {
        searchText = ""
        searchResults = []
    }

    /// Handles search text changes and triggers search when appropriate.
    func handleSearchTextChange(_ newValue: String) {
        if newValue.count >= 2 {
            performSearch()
        } else {
            searchResults = []
        }
    }

    /// Formats a date for display in the header.
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }
}
