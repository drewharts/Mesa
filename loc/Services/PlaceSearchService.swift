//
//  PlaceSearchService.swift
//  loc
//
//  Created by Andrew Hartsfield II on 4/22/25.
//

import Foundation
import CoreLocation
import FirebaseFirestore
import MapboxSearch

/// A service that uses Mesa backend for place search
class PlaceSearchService {
    // MARK: - Type Aliases for Callbacks
    
    typealias SuggestionsCallback = ([MesaPlaceSuggestion]) -> Void
    typealias DetailCallback = (DetailPlace) -> Void
    typealias ErrorCallback = (String) -> Void
    typealias DetailResultCallback = (Result<Any, Error>) -> Void
    
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
        print("🔍 [PlaceSearchService] searchPlaces called with query: '\(query)'")
        
        guard !query.isEmpty else {
            print("🔍 [PlaceSearchService] Query is empty, returning empty results")
            onResultsUpdated([])
            return
        }
        
        print("🔍 [PlaceSearchService] Calling mesaBackendService.fetchSuggestions...")
        mesaBackendService.fetchSuggestions(query: query, latitude: latitude, longitude: longitude) { result in
            print("🔍 [PlaceSearchService] Received response from mesaBackendService")
            switch result {
            case .success(let suggestions):
                print("✅ [PlaceSearchService] Successfully received \(suggestions.count) suggestions")
                for (index, suggestion) in suggestions.enumerated() {
                    print("🔍 [PlaceSearchService] Suggestion \(index + 1): \(suggestion.name) (ID: \(suggestion.id), Source: \(suggestion.source))")
                }
                DispatchQueue.main.async {
                    print("🔍 [PlaceSearchService] Calling onResultsUpdated with \(suggestions.count) suggestions")
                    onResultsUpdated(suggestions)
                }
            case .failure(let error):
                print("❌ [PlaceSearchService] Error from mesaBackendService: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    print("❌ [PlaceSearchService] Calling onError with: \(error.localizedDescription)")
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
        print("📍 [PlaceSearchService] selectSuggestion called for: \(suggestion.name) (ID: \(suggestion.id), Source: \(suggestion.source))")
        
        print("📍 [PlaceSearchService] Calling mesaBackendService.fetchPlaceDetails...")
        mesaBackendService.fetchPlaceDetails(placeId: suggestion.id, source: suggestion.source) { result in
            print("📍 [PlaceSearchService] Received response from mesaBackendService.fetchPlaceDetails")
            switch result {
            case .success(let details):
                print("✅ [PlaceSearchService] Successfully received place details for: \(details.name)")
                DispatchQueue.main.async {
                    print("📍 [PlaceSearchService] Calling onResultResolved with details for: \(details.name)")
                    onResultResolved(details)
                }
            case .failure(let error):
                print("❌ [PlaceSearchService] Error fetching place details: \(error.localizedDescription)")
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
        mesaBackendService.fetchPlaceDetails(placeId: placeId, source: "") { result in
            switch result {
            case .success(let details):
                completion(.success(details))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
} 
