import Foundation
import CoreLocation

// MARK: - Search Service Protocols

/// Protocol for place search suggestions
protocol PlaceSuggestion: Identifiable {
    var id: String { get }
    var name: String { get }
    var address: String? { get }
    var coordinate: CLLocationCoordinate2D { get }
}

/// Protocol for place search results
protocol PlaceResult: Identifiable {
    var id: String { get }
    var name: String { get }
    var address: String? { get }
    var coordinate: CLLocationCoordinate2D { get }
}

// MARK: - Mesa Backend Models

/// Model for location data in Mesa backend responses
struct MesaLocation: Codable {
    let latitude: Double
    let longitude: Double
}

/// Model for place details from Mesa backend
struct MesaPlaceDetails: Codable {
    let additional_data: [String: String]
    let address: String
    let id: String
    let location: MesaLocation
    let name: String
    let source: String
}

/// Response model for Mesa backend place details endpoint
struct MesaPlaceDetailsResponse: Codable {
    let place: MesaPlaceDetails
}

/// Model for suggestion data from Mesa backend
struct MesaSuggestion: Codable, Identifiable {
    let address: String
    let id: String
    let location: MesaLocation
    let name: String
    let source: String
}

/// Response model for Mesa backend suggestions endpoint
struct MesaSuggestionsResponse: Codable {
    let suggestions: [MesaSuggestion]
}

// MARK: - Place Suggestion and Result Models

/// Mesa implementation of PlaceSuggestion
struct MesaPlaceSuggestion: PlaceSuggestion {
    let id: String
    let name: String
    let address: String?
    let coordinate: CLLocationCoordinate2D
    let source: String
}

/// Mesa implementation of PlaceResult
struct MesaPlaceResult: PlaceResult {
    let id: String
    let name: String
    let address: String?
    let coordinate: CLLocationCoordinate2D
    let source: String
    let additional_data: [String: String]
}

// MARK: - Mesa Backend Service

/// Service class for the Mesa backend API
class MesaBackendService {
    private let baseURL = "https://mesa-backend-production.up.railway.app"
    private let session = URLSession.shared
    
    /// Fetch place suggestions from Mesa backend
    func fetchSuggestions(
        query: String,
        limit: Int = 5,
        provider: String = "all",
        completion: @escaping (Result<[MesaPlaceSuggestion], Error>) -> Void
    ) {
        guard !query.isEmpty else {
            completion(.success([]))
            return
        }
        
        guard var urlComponents = URLComponents(string: "\(baseURL)/search/suggestions") else {
            completion(.failure(NSError(domain: "MesaBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        // Add query parameters
        urlComponents.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "provider", value: provider)
        ]
        
        guard let url = urlComponents.url else {
            completion(.failure(NSError(domain: "MesaBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        let task = session.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(NSError(domain: "MesaBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "MesaBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                let response = try JSONDecoder().decode(MesaSuggestionsResponse.self, from: data)
                let suggestions = response.suggestions.map { mesaSuggestion in
                    MesaPlaceSuggestion(
                        id: mesaSuggestion.id,
                        name: mesaSuggestion.name,
                        address: mesaSuggestion.address,
                        coordinate: CLLocationCoordinate2D(
                            latitude: mesaSuggestion.location.latitude,
                            longitude: mesaSuggestion.location.longitude
                        ),
                        source: mesaSuggestion.source
                    )
                }
                completion(.success(suggestions))
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    /// Fetch place details from Mesa backend
    func fetchPlaceDetails(
        placeId: String,
        source: String,
        completion: @escaping (Result<MesaPlaceResult, Error>) -> Void
    ) {
        guard var urlComponents = URLComponents(string: "\(baseURL)/search/place-details") else {
            completion(.failure(NSError(domain: "MesaBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        // Add query parameters
        urlComponents.queryItems = [
            URLQueryItem(name: "place_id", value: placeId),
            URLQueryItem(name: "source", value: source)
        ]
        
        guard let url = urlComponents.url else {
            completion(.failure(NSError(domain: "MesaBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        print("🌐 Fetching place details from URL: \(url.absoluteString)")
        
        let task = session.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(NSError(domain: "MesaBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "MesaBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                let response = try JSONDecoder().decode(MesaPlaceDetailsResponse.self, from: data)
                let placeDetails = response.place
                let result = MesaPlaceResult(
                    id: placeDetails.id,
                    name: placeDetails.name,
                    address: placeDetails.address,
                    coordinate: CLLocationCoordinate2D(
                        latitude: placeDetails.location.latitude,
                        longitude: placeDetails.location.longitude
                    ),
                    source: placeDetails.source,
                    additional_data: placeDetails.additional_data
                )
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
}

// MARK: - Place Search Service

/// A service that uses Mesa backend for place search
class PlaceSearchService {
    // MARK: - Type Aliases for Callbacks
    
    typealias SuggestionsCallback = ([MesaPlaceSuggestion]) -> Void
    typealias DetailCallback = (MesaPlaceResult) -> Void
    typealias ErrorCallback = (String) -> Void
    typealias DetailResultCallback = (Result<MesaPlaceResult, Error>) -> Void
    
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
                // Fall back to using the suggestion as the result
                DispatchQueue.main.async {
                    onResultResolved(MesaPlaceResult(
                        id: suggestion.id,
                        name: suggestion.name,
                        address: suggestion.address,
                        coordinate: suggestion.coordinate,
                        source: suggestion.source,
                        additional_data: [:]
                    ))
                }
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

// MARK: - Integration Example

/*
 Example of how this would be integrated with the application:
 
 1. Initialize in a view model:
 
 class SearchViewModel: ObservableObject {
     private let placeSearchService = PlaceSearchService(useMesaBackend: true)
     
     func searchPlaces(query: String) {
         placeSearchService.searchPlaces(
             query: query,
             onResultsUpdated: { [weak self] suggestions in
                 if let mesaSuggestions = suggestions as? [MesaPlaceSuggestion] {
                     // Handle Mesa suggestions
                 } else {
                     // Handle other suggestion types
                 }
             },
             onError: { [weak self] error in
                 // Handle error
             }
         )
     }
 }
 
 2. Handle selected suggestions:
 
 func selectSuggestion(_ suggestion: Any) {
     placeSearchService.selectSuggestion(
         suggestion,
         onResultResolved: { [weak self] result in
             if let mesaResult = result as? MesaPlaceResult {
                 // Handle Mesa result
             } else {
                 // Handle other result types
             }
         }
     )
 }
 */ 