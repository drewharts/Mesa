import Foundation
import CoreLocation
import FirebaseFirestore
import MapboxSearch

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

/// Model for Google address components
struct GoogleAddressComponent: Codable {
    let long_name: String
    let short_name: String
    let types: [String]
}

/// Model for Google geometry
struct GoogleGeometry: Codable {
    let location: MesaLocation
    let viewport: GoogleViewport
}

/// Model for Google viewport
struct GoogleViewport: Codable {
    let northeast: MesaLocation
    let southwest: MesaLocation
}

/// Model for Google opening hours period
struct GoogleOpeningHoursPeriod: Codable {
    let close: GoogleTime
    let open: GoogleTime
}

/// Model for Google time
struct GoogleTime: Codable {
    let day: Int
    let time: String
}

/// Model for Google opening hours
struct GoogleOpeningHours: Codable {
    let open_now: Bool
    let periods: [GoogleOpeningHoursPeriod]
    let weekday_text: [String]
}

/// Model for Google place details
struct GooglePlaceDetails: Codable {
    let address_components: [GoogleAddressComponent]
    let business_status: String
    let city: String
    let formatted_address: String
    let geometry: GoogleGeometry
    let name: String
    let opening_hours: GoogleOpeningHours?
    let place_id: String
    let rating: Double?
    let types: [String]
    let website: String?
}

/// Model for place details from Mesa backend
struct MesaPlaceDetails: Codable {
    let additional_data: [String: String]
    let address: String
    let id: String
    let location: MesaLocation
    let name: String
    let provider: String
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
    
    /// Handle Google place details
    private func handleGooglePlaceDetails(_ data: [String: Any]) -> DetailPlace {
        var additionalData: [String: String] = [:]
        
        // Extract opening hours if available
        if let openingHours = data["opening_hours"] as? [String: Any] {
            if let weekdayText = openingHours["weekday_text"] as? [String] {
                additionalData["weekday_text"] = weekdayText.joined(separator: "|")
            }
        }
        
        // Extract location data
        var latitude: Double = 0
        var longitude: Double = 0
        if let geometry = data["geometry"] as? [String: Any],
           let location = geometry["location"] as? [String: Any] {
            latitude = location["lat"] as? Double ?? 0
            longitude = location["lng"] as? Double ?? 0
        }
        
        // Create DetailPlace object
        var detailPlace = DetailPlace()
        detailPlace.id = UUID()
        detailPlace.name = data["name"] as? String ?? ""
        detailPlace.address = data["formatted_address"] as? String
        detailPlace.coordinate = GeoPoint(latitude: latitude, longitude: longitude)
        detailPlace.rating = data["rating"] as? Double
        detailPlace.OpenHours = additionalData["weekday_text"]?.components(separatedBy: "|")
        detailPlace.priceLevel = data["price_level"] as? String
        detailPlace.categories = data["types"] as? [String]
        
        return detailPlace
    }
    
    /// Handle Mapbox place details
    private func handleMapboxPlaceDetails(_ data: [String: Any]) -> DetailPlace {
        var additionalData: [String: String] = [:]
        
        // Convert all additional data to strings
        for (key, value) in data {
            additionalData[key] = "\(value)"
        }
        
        // Create DetailPlace object
        var detailPlace = DetailPlace()
        detailPlace.id = UUID()
        detailPlace.name = data["name"] as? String ?? ""
        detailPlace.address = data["address"] as? String
        detailPlace.mapboxId = data["id"] as? String
        
        if let location = data["location"] as? [String: Any] {
            let latitude = location["latitude"] as? Double ?? 0
            let longitude = location["longitude"] as? Double ?? 0
            detailPlace.coordinate = GeoPoint(latitude: latitude, longitude: longitude)
        }
        
        detailPlace.categories = data["categories"] as? [String]
        detailPlace.phone = data["phone"] as? String
        detailPlace.rating = data["rating"] as? Double
        detailPlace.OpenHours = data["hours"] as? [String]
        detailPlace.description = data["description"] as? String
        detailPlace.priceLevel = data["price_level"] as? String
        
        return detailPlace
    }
    
    /// Handle local place details
    private func handleLocalPlaceDetails(_ data: [String: Any]) -> DetailPlace {
        // Create a new DetailPlace object
        var detailPlace = DetailPlace()
        
        // Extract the additional_data which contains most of the fields
        if let additionalData = data["additional_data"] as? [String: Any] {
            // Set basic fields
            detailPlace.id = UUID(uuidString: additionalData["id"] as? String ?? "") ?? UUID()
            detailPlace.name = additionalData["name"] as? String ?? ""
            detailPlace.address = additionalData["address"] as? String
            detailPlace.city = additionalData["city"] as? String
            detailPlace.mapboxId = additionalData["mapboxId"] as? String
            
            // Set categories
            detailPlace.categories = additionalData["categories"] as? [String]
            
            // Set OpenHours
            detailPlace.OpenHours = additionalData["OpenHours"] as? [String]
            
            // Set coordinate
            if let coordinate = additionalData["coordinate"] as? [String: Any],
               let latitude = coordinate["latitude"] as? Double,
               let longitude = coordinate["longitude"] as? Double {
                detailPlace.coordinate = GeoPoint(latitude: latitude, longitude: longitude)
            }
        }
        
        return detailPlace
    }
    
    /// Fetch place details from Mesa backend
    func fetchPlaceDetails(
        placeId: String,
        source: String,
        completion: @escaping (Result<Any, Error>) -> Void
    ) {
        guard var urlComponents = URLComponents(string: "\(baseURL)/search/place-details") else {
            completion(.failure(NSError(domain: "MesaBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        // Add query parameters
        urlComponents.queryItems = [
            URLQueryItem(name: "place_id", value: placeId),
            URLQueryItem(name: "provider", value: source)
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
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let place = json["place"] as? [String: Any],
                   let additionalData = place["additional_data"] as? [String: Any] {
                    
                    let result: Any
                    switch source {
                    case "google":
                        result = self.handleGooglePlaceDetails(additionalData)
                    case "mapbox":
                        result = self.handleMapboxPlaceDetails(additionalData)
                    case "local":
                        result = self.handleLocalPlaceDetails(place)
                    default:
                        throw NSError(domain: "MesaBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unsupported provider"])
                    }
                    
                    completion(.success(result))
                } else {
                    throw NSError(domain: "MesaBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
                }
            } catch {
                print("Error decoding place details: \(error)")
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
    typealias DetailCallback = (Any) -> Void
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
