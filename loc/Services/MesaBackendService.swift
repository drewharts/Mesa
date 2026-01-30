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
    private let session: URLSession
    
    init() {
        // Create custom URLSession configuration to avoid connection pooling issues
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.httpMaximumConnectionsPerHost = 4
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.waitsForConnectivity = true
        self.session = URLSession(configuration: configuration)
    }
    
    /// Fetch place suggestions from Mesa backend
    func fetchSuggestions(
        query: String,
        limit: Int = 5,
        provider: String = "google",
        latitude: Double? = nil,
        longitude: Double? = nil,
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
        var queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "provider", value: provider)
        ]

        // Add location parameters if provided
        if let latitude = latitude {
            queryItems.append(URLQueryItem(name: "latitude", value: String(latitude)))
        }
        if let longitude = longitude {
            queryItems.append(URLQueryItem(name: "longitude", value: String(longitude)))
        }

        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            completion(.failure(NSError(domain: "MesaBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        let task = session.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "MesaBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(NSError(domain: "MesaBackend", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned status code \(httpResponse.statusCode)"])))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "MesaBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                let response = try JSONDecoder().decode(MesaSuggestionsResponse.self, from: data)
                
                let suggestions = response.suggestions.map { mesaSuggestion in
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
        
        let task = session.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "MesaBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(NSError(domain: "MesaBackend", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned status code \(httpResponse.statusCode)"])))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "MesaBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                // First parse the data into a dictionary
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                
                // Extract the "place" object
                guard let placeDict = json?["place"] as? [String: Any] else {
                    throw NSError(domain: "MesaBackend", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON structure"])
                }
                
                // Create a DetailPlace object manually
                var detailPlace = DetailPlace()
                
                // CRITICAL: Always use the backend's ID - never create a new one!
                // Creating a new ID would orphan the place in the backend
                guard let idString = placeDict["id"] as? String,
                      let placeId = UUID(uuidString: idString) else {
                    throw NSError(domain: "MesaBackend", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid place ID from backend"])
                }
                detailPlace.id = placeId
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
                detailPlace.userRatingsTotal = placeDict["ratingCount"] as? Int
                detailPlace.reservable = placeDict["reservable"] as? Bool
                detailPlace.servesBreakfast = placeDict["servesBreakfast"] as? Bool
                detailPlace.serversLunch = placeDict["servesLunch"] as? Bool
                detailPlace.serversDinner = placeDict["servesDinner"] as? Bool
                detailPlace.Instagram = placeDict["instagram"] as? String
                detailPlace.X = placeDict["twitter"] as? String
                detailPlace.menuUrl = placeDict["menuUrl"] as? String
                detailPlace.websiteUrl = placeDict["website"] as? String

                // Manually extract coordinates and create CLLocationCoordinate2D
                if let locationDict = placeDict["location"] as? [String: Any],
                   let latitude = locationDict["latitude"] as? Double,
                   let longitude = locationDict["longitude"] as? Double {
                    detailPlace.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                }
                
                completion(.success(detailPlace))
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }

    /// Fetch AI-powered place suggestions from Mesa backend
    func fetchAISuggestions(
        query: String,
        latitude: Double,
        longitude: Double,
        limit: Int = 5,
        completion: @escaping (Result<[DetailPlace], Error>) -> Void
    ) {
        guard !query.isEmpty else {
            print("🤖 [MesaBackend] AI suggestions: empty query, returning empty")
            completion(.success([]))
            return
        }

        print("🤖 [MesaBackend] Fetching AI suggestions for: '\(query)'")

        guard let url = URL(string: "\(baseURL)/search/ai-suggestions") else {
            print("🤖 [MesaBackend] Invalid URL")
            completion(.failure(NSError(domain: "MesaBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "text": query,
            "latitude": latitude,
            "longitude": longitude,
            "limit": limit
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }

        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("🤖 [MesaBackend] AI suggestions network error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                print("🤖 [MesaBackend] AI suggestions: invalid server response")
                completion(.failure(NSError(domain: "MesaBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])))
                return
            }

            print("🤖 [MesaBackend] AI suggestions response status: \(httpResponse.statusCode)")

            guard (200...299).contains(httpResponse.statusCode) else {
                if let data = data, let body = String(data: data, encoding: .utf8) {
                    print("🤖 [MesaBackend] AI suggestions error body: \(body.prefix(500))")
                }
                completion(.failure(NSError(domain: "MesaBackend", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned status code \(httpResponse.statusCode)"])))
                return
            }

            guard let data = data else {
                print("🤖 [MesaBackend] AI suggestions: no data received")
                completion(.failure(NSError(domain: "MesaBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            do {
                let places = try self.parseAISuggestionsResponse(data: data)
                print("🤖 [MesaBackend] AI suggestions parsed \(places.count) places")
                completion(.success(places))
            } catch {
                print("🤖 [MesaBackend] AI suggestions parse error: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }

        task.resume()
    }

    /// Parse AI suggestions response into DetailPlace array
    private func parseAISuggestionsResponse(data: Data) throws -> [DetailPlace] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let suggestionsArray = json["suggestions"] as? [[String: Any]] else {
            throw NSError(domain: "MesaBackend", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid AI suggestions response structure"])
        }

        return suggestionsArray.compactMap { suggestionDict -> DetailPlace? in
            guard let idString = suggestionDict["id"] as? String,
                  let placeId = UUID(uuidString: idString),
                  let name = suggestionDict["name"] as? String else {
                return nil
            }

            var detailPlace = DetailPlace()
            detailPlace.id = placeId
            detailPlace.name = name
            detailPlace.address = suggestionDict["address"] as? String
            detailPlace.city = suggestionDict["city"] as? String
            detailPlace.description = suggestionDict["description"] as? String
            detailPlace.mapboxId = suggestionDict["mapboxId"] as? String
            detailPlace.categories = suggestionDict["categories"] as? [String]
            detailPlace.openHours = suggestionDict["openHours"] as? [String]
            detailPlace.phone = suggestionDict["phone"] as? String
            detailPlace.priceLevel = suggestionDict["priceLevel"] as? String
            detailPlace.rating = suggestionDict["rating"] as? Double
            detailPlace.userRatingsTotal = suggestionDict["ratingCount"] as? Int
            detailPlace.reservable = suggestionDict["reservable"] as? Bool
            detailPlace.servesBreakfast = suggestionDict["servesBreakfast"] as? Bool
            detailPlace.serversLunch = suggestionDict["servesLunch"] as? Bool
            detailPlace.serversDinner = suggestionDict["servesDinner"] as? Bool
            detailPlace.Instagram = suggestionDict["instagram"] as? String
            detailPlace.X = suggestionDict["twitter"] as? String
            detailPlace.menuUrl = suggestionDict["menuUrl"] as? String
            detailPlace.websiteUrl = suggestionDict["website"] as? String
            detailPlace.aiSuggestionReason = suggestionDict["aiSuggestionReason"] as? String

            // Extract thumbnail URL for photos
            if let thumbnailUrl = suggestionDict["thumbnailUrl"] as? String {
                detailPlace.photoUrls = [thumbnailUrl]
            }

            // Extract coordinates
            if let coordDict = suggestionDict["coordinate"] as? [String: Any],
               let latitude = coordDict["latitude"] as? Double,
               let longitude = coordDict["longitude"] as? Double {
                detailPlace.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            }

            return detailPlace
        }
    }
}
