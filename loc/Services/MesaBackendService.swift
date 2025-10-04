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
    private let baseURL = "https://mesa-backend-staging.up.railway.app"
    private let session = URLSession.shared
    
    /// Fetch place suggestions from Mesa backend
    func fetchSuggestions(
        query: String,
        limit: Int = 5,
        provider: String = "all",
        completion: @escaping (Result<[MesaPlaceSuggestion], Error>) -> Void
    ) {
        print("🌐 [MesaBackendService] fetchSuggestions called with query: '\(query)', limit: \(limit), provider: '\(provider)'")
        
        guard !query.isEmpty else {
            print("🌐 [MesaBackendService] Query is empty, returning empty results")
            completion(.success([]))
            return
        }
        
        guard var urlComponents = URLComponents(string: "\(baseURL)/search/suggestions") else {
            print("❌ [MesaBackendService] Failed to create URL components from: \(baseURL)/search/suggestions")
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
            print("❌ [MesaBackendService] Failed to create URL from components")
            completion(.failure(NSError(domain: "MesaBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        print("🌐 [MesaBackendService] Making request to: \(url.absoluteString)")
        
        let task = session.dataTask(with: url) { data, response, error in
            print("🌐 [MesaBackendService] Network request completed")
            
            if let error = error {
                print("❌ [MesaBackendService] Network error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [MesaBackendService] Invalid HTTP response")
                completion(.failure(NSError(domain: "MesaBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])))
                return
            }
            
            print("🌐 [MesaBackendService] HTTP Status Code: \(httpResponse.statusCode)")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ [MesaBackendService] HTTP error with status code: \(httpResponse.statusCode)")
                completion(.failure(NSError(domain: "MesaBackend", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned status code \(httpResponse.statusCode)"])))
                return
            }
            
            guard let data = data else {
                print("❌ [MesaBackendService] No data received")
                completion(.failure(NSError(domain: "MesaBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            print("🌐 [MesaBackendService] Received \(data.count) bytes of data")
            
            // Print raw data
            if let rawString = String(data: data, encoding: .utf8) {
                print("📦 [MesaBackendService] Raw API Response: \(rawString)")
            }
            
            do {
                let response = try JSONDecoder().decode(MesaSuggestionsResponse.self, from: data)
                print("✅ [MesaBackendService] Successfully decoded response with \(response.suggestions.count) suggestions")
                
                let suggestions = response.suggestions.map { mesaSuggestion in
                    print("🔍 [MesaBackendService] Processing suggestion: \(mesaSuggestion.name) (ID: \(mesaSuggestion.id), Source: \(mesaSuggestion.source))")
                    return MesaPlaceSuggestion(
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
                
                print("✅ [MesaBackendService] Successfully created \(suggestions.count) MesaPlaceSuggestion objects")
                completion(.success(suggestions))
            } catch {
                print("❌ [MesaBackendService] JSON decoding error: \(error.localizedDescription)")
                
                // Additional debugging information
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .dataCorrupted(let context):
                        print("❌ [MesaBackendService] Data corrupted: \(context)")
                    case .keyNotFound(let key, let context):
                        print("❌ [MesaBackendService] Key not found: \(key), context: \(context)")
                    case .typeMismatch(let type, let context):
                        print("❌ [MesaBackendService] Type mismatch: \(type), context: \(context)")
                    case .valueNotFound(let type, let context):
                        print("❌ [MesaBackendService] Value not found: \(type), context: \(context)")
                    @unknown default:
                        print("❌ [MesaBackendService] Unknown decoding error")
                    }
                }
                
                completion(.failure(error))
            }
        }
        
        print("🌐 [MesaBackendService] Starting network request...")
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
        //TODO: I think this should be the same id that was created in the backend
        detailPlace.id = UUID()
        detailPlace.name = data["name"] as? String ?? ""
        detailPlace.address = data["formatted_address"] as? String
        detailPlace.coordinate = GeoPoint(latitude: latitude, longitude: longitude)
        detailPlace.rating = data["rating"] as? Double
        detailPlace.openHours = additionalData["weekday_text"]?.components(separatedBy: "|")
        detailPlace.priceLevel = data["price_level"] as? String
        detailPlace.categories = data["types"] as? [String]
        
        return detailPlace
    }
    
    /// Handle Mapbox place details
    private func handleMapboxPlaceDetails(_ data: [String: Any]) -> DetailPlace {
        // Create DetailPlace object
        var detailPlace = DetailPlace()
        
        // Extract the additional_data which contains most of the fields
        if let additionalData = data["additional_data"] as? [String: Any] {
            // Set basic fields
            detailPlace.id = UUID()
            detailPlace.name = additionalData["name"] as? String ?? ""
            detailPlace.address = additionalData["full_address"] as? String
            detailPlace.mapboxId = additionalData["mapbox_id"] as? String
            
            // Set city and region from context
            if let context = additionalData["context"] as? [String: Any],
               let place = context["place"] as? [String: Any] {
                detailPlace.city = place["name"] as? String
            }
            
            // Set categories from poi_category
            detailPlace.categories = additionalData["poi_category"] as? [String]
            
            // Set coordinate from coordinates
            if let coordinates = additionalData["coordinates"] as? [String: Any],
               let latitude = coordinates["latitude"] as? Double,
               let longitude = coordinates["longitude"] as? Double {
                detailPlace.coordinate = GeoPoint(latitude: latitude, longitude: longitude)
            }
            
            // Additional metadata fields are available but not currently used:
            // - metadata: additionalData["metadata"] as? [String: Any]
            // - feature_type: additionalData["feature_type"] as? String
            // - operational_status: additionalData["operational_status"] as? String
            // - maki: additionalData["maki"] as? String
            // - language: additionalData["language"] as? String
        }
        
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
            detailPlace.openHours = additionalData["OpenHours"] as? [String]
            
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
        completion: @escaping (Result<DetailPlace, Error>) -> Void
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
        
        print("🌐 [MesaBackendService] fetchPlaceDetails called with placeId: '\(placeId)', source: '\(source)'")
        print("🌐 [MesaBackendService] Fetching place details from URL: \(url.absoluteString)")
        
        let task = session.dataTask(with: url) { data, response, error in
            print("🌐 [MesaBackendService] fetchPlaceDetails network request completed")
            
            if let error = error {
                print("❌ [MesaBackendService] fetchPlaceDetails network error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [MesaBackendService] fetchPlaceDetails invalid HTTP response")
                completion(.failure(NSError(domain: "MesaBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])))
                return
            }
            
            print("🌐 [MesaBackendService] fetchPlaceDetails HTTP Status Code: \(httpResponse.statusCode)")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ [MesaBackendService] fetchPlaceDetails HTTP error with status code: \(httpResponse.statusCode)")
                completion(.failure(NSError(domain: "MesaBackend", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned status code \(httpResponse.statusCode)"])))
                return
            }
            
            guard let data = data else {
                print("❌ [MesaBackendService] fetchPlaceDetails no data received")
                completion(.failure(NSError(domain: "MesaBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            print("🌐 [MesaBackendService] fetchPlaceDetails received \(data.count) bytes of data")
            
            // Print raw data
            if let rawString = String(data: data, encoding: .utf8) {
                print("📦 [MesaBackendService] fetchPlaceDetails Raw API Response: \(rawString)")
            }
            
            do {
                print("🌐 [MesaBackendService] fetchPlaceDetails attempting to parse JSON...")
                
                // First parse the data into a dictionary
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                print("🌐 [MesaBackendService] fetchPlaceDetails successfully parsed JSON")
                
                // Extract the "place" object
                guard let placeDict = json?["place"] as? [String: Any] else {
                    print("❌ [MesaBackendService] fetchPlaceDetails failed to extract 'place' object from JSON")
                    throw NSError(domain: "MesaBackend", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON structure"])
                }
                
                print("🌐 [MesaBackendService] fetchPlaceDetails successfully extracted place object")
                
                // Create a DetailPlace object manually
                var detailPlace = DetailPlace()
                detailPlace.id = UUID(uuidString: placeDict["id"] as? String ?? "") ?? UUID()
                detailPlace.name = placeDict["name"] as? String ?? ""
                detailPlace.address = placeDict["address"] as? String
                detailPlace.city = placeDict["city"] as? String
                detailPlace.description = placeDict["description"] as? String
                detailPlace.mapboxId = placeDict["mapboxId"] as? String
                detailPlace.categories = placeDict["categories"] as? [String]
                detailPlace.openHours = placeDict["openHours"] as? [String]
                detailPlace.phone = placeDict["phone"] as? String
                detailPlace.priceLevel = placeDict["priceLevel"] as? String
                detailPlace.rating = placeDict["rating"] as? Double
                detailPlace.reservable = placeDict["reservable"] as? Bool
                detailPlace.servesBreakfast = placeDict["servesBreakfast"] as? Bool
                detailPlace.serversLunch = placeDict["servesLunch"] as? Bool
                detailPlace.serversDinner = placeDict["servesDinner"] as? Bool
                detailPlace.Instagram = placeDict["instagram"] as? String
                detailPlace.X = placeDict["twitter"] as? String
                
                // Manually extract coordinates and create GeoPoint
                if let locationDict = placeDict["location"] as? [String: Any],
                   let latitude = locationDict["latitude"] as? Double,
                   let longitude = locationDict["longitude"] as? Double {
                    detailPlace.coordinate = GeoPoint(latitude: latitude, longitude: longitude)
                    print("🌐 [MesaBackendService] fetchPlaceDetails extracted coordinates: (\(latitude), \(longitude))")
                }
                
                print("✅ [MesaBackendService] fetchPlaceDetails successfully created DetailPlace: \(detailPlace.name)")
                completion(.success(detailPlace))
            } catch {
                print("❌ [MesaBackendService] fetchPlaceDetails error parsing place details: \(error)")
                completion(.failure(error))
            }
        }
        
        print("🌐 [MesaBackendService] fetchPlaceDetails starting network request...")
        task.resume()
    }
}
