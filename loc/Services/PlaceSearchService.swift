//
//  PlaceSearchService.swift
//  loc
//
//  Created by Andrew Hartsfield II on 4/22/25.
//

import Foundation
import CoreLocation

/// A service that uses Mesa backend for place search
class PlaceSearchService {
    // MARK: - Type Aliases for Callbacks

    typealias SuggestionsCallback = ([MesaPlaceSuggestion]) -> Void
    typealias DetailCallback = (DetailPlace) -> Void
    typealias ErrorCallback = (String) -> Void
    typealias DetailResultCallback = (Result<Any, Error>) -> Void
    typealias AISuggestionsCallback = ([DetailPlace]) -> Void
    
    // MARK: - Properties
    
    private let mesaBackendService = MesaBackendService()
    
    // MARK: - Public Methods
    
    /// Search for place suggestions
    /// - Parameters:
    ///   - query: The search query
    ///   - latitude: Optional user's latitude for location-aware search
    ///   - longitude: Optional user's longitude for location-aware search
    ///   - onResultsUpdated: Callback with search results
    ///   - onError: Callback for errors
    func searchPlaces(
        query: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        onResultsUpdated: @escaping SuggestionsCallback,
        onError: @escaping ErrorCallback
    ) {
        guard !query.isEmpty else {
            onResultsUpdated([])
            return
        }
        
        mesaBackendService.fetchSuggestions(query: query, provider: "google", latitude: latitude, longitude: longitude) { result in
            switch result {
            case .success(let suggestions):
                DispatchQueue.main.async {
                    onResultsUpdated(suggestions)
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    onError(error.localizedDescription)
                }
            }
        }
    }
    
    /// Select a suggestion to get more details
    /// - Parameters:
    ///   - suggestion: The selected suggestion
    ///   - onResultResolved: Callback with detailed result
    func selectSuggestion(
        _ suggestion: MesaPlaceSuggestion,
        onResultResolved: @escaping DetailCallback
    ) {
        mesaBackendService.fetchPlaceDetails(placeId: suggestion.id, source: suggestion.source) { result in
            switch result {
            case .success(let details):
                DispatchQueue.main.async {
                    onResultResolved(details)
                }
            case .failure(let error):
                print("❌ [PlaceSearchService] fetchPlaceDetails failed: \(error.localizedDescription)")
                // Error fetching place details - silently handle
                break
            }
        }
    }
    
    /// Retrieve a place by ID
    /// - Parameters:
    ///   - placeId: The ID of the place
    ///   - completion: Callback with place details or error
    func retrievePlaceById(
        placeId: String,
        completion: @escaping DetailResultCallback
    ) {
        // Default to Google as the source for recent place lookups
        mesaBackendService.fetchPlaceDetails(placeId: placeId, source: "google") { result in
            switch result {
            case .success(let details):
                completion(.success(details))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Search for AI-powered place suggestions using natural language queries
    /// - Parameters:
    ///   - query: The natural language search query
    ///   - latitude: User's latitude for location-aware results
    ///   - longitude: User's longitude for location-aware results
    ///   - onResultsUpdated: Callback with AI suggestions
    ///   - onError: Callback for errors
    func searchAISuggestions(
        query: String,
        latitude: Double,
        longitude: Double,
        onResultsUpdated: @escaping AISuggestionsCallback,
        onError: @escaping ErrorCallback
    ) {
        guard !query.isEmpty else {
            onResultsUpdated([])
            return
        }

        mesaBackendService.fetchAISuggestions(query: query, latitude: latitude, longitude: longitude) { result in
            switch result {
            case .success(let suggestions):
                DispatchQueue.main.async {
                    onResultsUpdated(suggestions)
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    onError(error.localizedDescription)
                }
            }
        }
    }
} 
