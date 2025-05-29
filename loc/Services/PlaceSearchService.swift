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
    ///   - onResultsUpdated: Callback with search results
    ///   - onError: Callback for errors
    func searchPlaces(
        query: String,
        onResultsUpdated: @escaping SuggestionsCallback,
        onError: @escaping ErrorCallback
    ) {
        mesaBackendService.fetchSuggestions(query: query) { result in
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
                print("Error fetching place details: \(error.localizedDescription)")
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
